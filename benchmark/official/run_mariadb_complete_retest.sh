#!/usr/bin/env bash
# But Is It True? Lab — complete MariaDB retest, limited then unrestricted.
# Preserves old results, images, containers, and the database's original volume.
set -uo pipefail
umask 077

LANGS=(go rust node python php cpp java elixir ruby csharp v nim zig)
LEVELS=(1 10 50 100 250 500 1000)
NETWORK=api_benchmark_network
RUNNER=api-benchmark-runner
BASE_DB=benchmark_mariadb
DURATION=30
WARMUP=30
COOLDOWN=15
STAMP=$(date -u +%Y%m%d_%H%M%S)
OUT="benchmark/results/mariadb_retest_${STAMP}"
mkdir -p "$OUT"
OUT=$(realpath "$OUT")
TMP=$(mktemp -d /tmp/mariadb-official-env.XXXXXXXX)
SUMMARY="$OUT/summary.csv"
CURRENT_API=""
CURRENT_DB=""
ORIGINAL_DB_RUNNING=0
SUCCESS=0
FAILURES=0

exec 9>"benchmark/results/mariadb_official.lock"
if ! flock -n 9; then
    echo 'ERROR: A MariaDB official benchmark is already running.'
    rm -rf "$TMP"
    exit 1
fi

cleanup() {
    local rc=$?
    trap - EXIT INT TERM
    if [ -n "$CURRENT_API" ]; then
        docker rm -f "$CURRENT_API" >/dev/null 2>&1 || true
    fi
    if [ -n "$CURRENT_DB" ]; then
        docker rm -f "$CURRENT_DB" >/dev/null 2>&1 || true
    fi
    if [ "$ORIGINAL_DB_RUNNING" -eq 1 ]; then
        docker start "$BASE_DB" >/dev/null 2>&1 || true
        # The original database's previously raised limit was only temporary.
        # Restore that runtime setting once the original DB is ready again.
        if wait_for_db "$BASE_DB"; then
            ensure_db_capacity "$BASE_DB" >/dev/null 2>&1 || true
        fi
    fi
    rm -rf "$TMP"
    printf '%s\n' "$rc" > "$OUT/exit_code.txt"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# Convert a JSON array from docker inspect to a NUL-delimited shell array.
read_container_command() {
    local container=$1
    mapfile -d '' -t ENTRY < <(
        docker inspect "$container" --format '{{json .Config.Entrypoint}}' | \
        python3 -c 'import sys,json; x=json.load(sys.stdin) or []; sys.stdout.buffer.write(b"\0".join(v.encode() for v in x) + (b"\0" if x else b""))'
    )
    mapfile -d '' -t CMD < <(
        docker inspect "$container" --format '{{json .Config.Cmd}}' | \
        python3 -c 'import sys,json; x=json.load(sys.stdin) or []; sys.stdout.buffer.write(b"\0".join(v.encode() for v in x) + (b"\0" if x else b""))'
    )
    IMAGE=$(docker inspect "$container" --format '{{.Image}}')
    EXTRA_EP=()
    EXEC_CMD=("${CMD[@]}")
    if [ "${#ENTRY[@]}" -gt 0 ]; then
        EXTRA_EP=(--entrypoint "${ENTRY[0]}")
        EXEC_CMD=("${ENTRY[@]:1}" "${CMD[@]}")
    else
        EXTRA_EP=(--entrypoint '')
    fi
}

write_envfile() {
    docker inspect "$1" --format '{{range .Config.Env}}{{println .}}{{end}}' > "$2"
    chmod 600 "$2"
}

wait_for_db() {
    local ct=$1
    local state
    for _ in $(seq 1 90); do
        state=$(docker inspect "$ct" --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' 2>/dev/null || true)
        if [ "$state" = healthy ] || [ "$state" = running ]; then
            # A running container may not yet be ready to accept SQL.
            if docker exec "$ct" sh -c 'MYSQL_PWD="${MARIADB_ROOT_PASSWORD:-${MYSQL_ROOT_PASSWORD:-}}" mariadb -uroot -Nse "SELECT 1"' >/dev/null 2>&1; then
                return 0
            fi
        fi
        sleep 2
    done
    return 1
}

ensure_db_capacity() {
    local ct=$1
    docker exec "$ct" sh -c \
        'MYSQL_PWD="${MARIADB_ROOT_PASSWORD:-${MYSQL_ROOT_PASSWORD:-}}" mariadb -uroot -e "SET GLOBAL max_connections=2000"' \
        || return 1
    local max_connections
    max_connections=$(docker exec "$ct" sh -c \
        'MYSQL_PWD="$MARIADB_PASSWORD" mariadb -u benchmark -Nse "SELECT @@GLOBAL.max_connections"' 2>/dev/null || true)
    echo "Database max_connections=$max_connections"
    [ "$max_connections" = 2000 ]
}

record_result() {
    # profile, language, concurrency, requests, errors, rps, status
    printf '%s,%s,%s,%s,%s,%s,%s\n' "$1" "$2" "$3" "$4" "$5" "$6" "$7" >> "$SUMMARY"
    if [ "$7" != PASS ]; then FAILURES=$((FAILURES+1)); fi
}

# Validate all required sources before touching the database.
for command in docker python3 flock timeout; do
    command -v "$command" >/dev/null || { echo "ERROR: missing $command"; exit 1; }
done
docker container inspect "$BASE_DB" >/dev/null || exit 1
docker network inspect "$NETWORK" >/dev/null || exit 1
docker image inspect "$RUNNER" >/dev/null || exit 1
for LANG in "${LANGS[@]}"; do
    docker container inspect "benchmark_${LANG}_mariadb" >/dev/null || {
        echo "ERROR: missing source container benchmark_${LANG}_mariadb"; exit 1;
    }
done
DATA_MOUNT=$(docker inspect "$BASE_DB" \
    --format '{{range .Mounts}}{{if eq .Destination "/var/lib/mysql"}}PRESENT{{end}}{{end}}')
if [ "$DATA_MOUNT" != PRESENT ]; then
    echo 'SAFETY STOP: MariaDB /var/lib/mysql is not on a volume/bind mount.'
    echo 'A clone would not share the database records. No containers were changed.'
    exit 1
fi

if [ "$(docker inspect "$BASE_DB" --format '{{.State.Running}}')" = true ]; then
    ORIGINAL_DB_RUNNING=1
fi

{
    echo "UTC_START=$(date -u --iso-8601=seconds)"
    echo 'PROFILES=limited,unlimited'
    echo "LANGUAGES=${LANGS[*]}"
    echo "LEVELS=${LEVELS[*]}"
    echo "DURATION=$DURATION"
    echo "WARMUP=$WARMUP"
    echo "COOLDOWN=$COOLDOWN"
    echo "NETWORK=$NETWORK"
    echo "DB_BASE_IMAGE=$(docker inspect "$BASE_DB" --format '{{.Image}}')"
    echo "REPO_COMMIT=$(git rev-parse HEAD 2>/dev/null || echo unknown)"
    uname -a
    lscpu
    free -h
} > "$OUT/environment.txt" 2>&1

echo 'profile,language,concurrency,requests,errors,requests_per_second,status' > "$SUMMARY"
echo "Results: $OUT"
echo 'Both profiles will run even if some concurrency levels report errors.'

# Stop every other benchmark service; do not touch unrelated production containers.
echo 'Stopping running benchmark_* containers...'
while IFS= read -r container; do
    [ -n "$container" ] || continue
    docker stop "$container" >/dev/null 2>&1 || true
done < <(docker ps --format '{{.Names}}' | grep '^benchmark_' || true)

write_envfile "$BASE_DB" "$TMP/mariadb.env"
read_container_command "$BASE_DB"
DB_IMAGE=$IMAGE
DB_EP=("${EXTRA_EP[@]}")
DB_CMD=("${EXEC_CMD[@]}")

for PROFILE in limited unlimited; do
    echo
    echo "=================== $PROFILE ==================="
    DB_CLONE="official_maria_${STAMP}_${PROFILE}"
    db_flags=()
    if [ "$PROFILE" = limited ]; then
        db_flags=(--cpus 4 --memory 8g --memory-swap 8g)
    fi

    # --volumes-from preserves the existing MariaDB data/config mounts.
    if ! docker create \
        --name "$DB_CLONE" \
        --network "$NETWORK" --network-alias benchmark_mariadb \
        --volumes-from "$BASE_DB" \
        --env-file "$TMP/mariadb.env" \
        "${db_flags[@]}" \
        "${DB_EP[@]}" \
        "$DB_IMAGE" "${DB_CMD[@]}" > "$OUT/${PROFILE}_db_create.txt" 2>&1; then
        echo "ERROR: Could not create $PROFILE database clone."
        exit 1
    fi
    CURRENT_DB=$DB_CLONE
    if ! docker start "$DB_CLONE" >/dev/null; then
        echo 'ERROR: Could not start database clone.'
        docker logs "$DB_CLONE" > "$OUT/${PROFILE}_db_errors.txt" 2>&1 || true
        exit 1
    fi
    if ! wait_for_db "$DB_CLONE" || ! ensure_db_capacity "$DB_CLONE"; then
        echo "ERROR: $PROFILE database startup/connection configuration failed."
        docker logs "$DB_CLONE" > "$OUT/${PROFILE}_db_errors.txt" 2>&1 || true
        exit 1
    fi
    DB_LIMITS=$(docker inspect "$DB_CLONE" --format '{{.HostConfig.NanoCpus}} {{.HostConfig.Memory}} {{.HostConfig.CpuQuota}} {{.HostConfig.CpusetCpus}}')
    echo "DB resource settings: $DB_LIMITS"
    printf '%s\n' "$DB_LIMITS" > "$OUT/${PROFILE}_db_resource_limits.txt"
    if [ "$PROFILE" = unlimited ]; then
        [ "$DB_LIMITS" = '0 0 0 ' ] || [ "$DB_LIMITS" = '0 0 -1 ' ] || {
            echo "SAFETY STOP: Unrestricted DB has limits: $DB_LIMITS"; exit 1;
        }
    fi

    for LANG in "${LANGS[@]}"; do
        SRC="benchmark_${LANG}_mariadb"
        API="official_maria_${STAMP}_${PROFILE}_${LANG}"
        DIR="$OUT/$PROFILE/$LANG"
        mkdir -p "$DIR"
        echo
        echo "========== $PROFILE / $LANG =========="

        write_envfile "$SRC" "$TMP/${LANG}.env"
        read_container_command "$SRC"
        api_flags=()
        if [ "$PROFILE" = limited ]; then
            api_flags=(--cpus 2 --memory 2g --memory-swap 2g)
        fi
        # Use an image ID and env from the tested implementation: no rebuild.
        if ! docker create \
            --name "$API" \
            --network "$NETWORK" --network-alias "$SRC" \
            --volumes-from "$SRC" \
            --env-file "$TMP/${LANG}.env" \
            "${api_flags[@]}" \
            "${EXTRA_EP[@]}" \
            "$IMAGE" "${EXEC_CMD[@]}" > "$DIR/create.txt" 2>&1; then
            echo "CREATE FAILED: $LANG"
            record_result "$PROFILE" "$LANG" 0 0 0 0 CREATE_FAILED
            continue
        fi
        CURRENT_API=$API

        if [ "$PROFILE" = unlimited ]; then
            LIMITS=$(docker inspect "$API" --format '{{.HostConfig.NanoCpus}} {{.HostConfig.Memory}} {{.HostConfig.CpuQuota}} {{.HostConfig.CpusetCpus}}')
            if [ "$LIMITS" != '0 0 0 ' ] && [ "$LIMITS" != '0 0 -1 ' ]; then
                echo "RESOURCE CHECK FAILED: $LIMITS"
                record_result "$PROFILE" "$LANG" 0 0 0 0 RESOURCE_FAILED
                docker rm -f "$API" >/dev/null 2>&1 || true
                CURRENT_API=""
                continue
            fi
        fi
        docker inspect "$API" \
          --format 'Image={{.Image}} CPUs={{.HostConfig.NanoCpus}} Mem={{.HostConfig.Memory}} CPUQuota={{.HostConfig.CpuQuota}}' \
          > "$DIR/resources.txt"

        if ! docker start "$API" > "$DIR/start.txt" 2>&1; then
            echo "START FAILED: $LANG"
            for C in "${LEVELS[@]}"; do
                record_result "$PROFILE" "$LANG" "$C" 0 0 0 START_FAILED
            done
            docker rm -f "$API" >/dev/null 2>&1 || true
            CURRENT_API=""
            continue
        fi

        READY=0
        for _ in $(seq 1 45); do
            if docker run --rm --network "$NETWORK" \
                  curlimages/curl:8.12.1 -fsS --connect-timeout 2 --max-time 5 \
                  "http://${SRC}:8080/parent/50000" > "$DIR/preflight.json" 2>/dev/null \
               && python3 - "$DIR/preflight.json" <<'PY'
import json, sys
try:
    with open(sys.argv[1]) as f: row = json.load(f)
    assert row['id'] == 50000
    assert all(k in row for k in ('account_number', 'status', 'created_at', 'payload'))
except Exception: sys.exit(1)
PY
            then
                READY=1
                break
            fi
            sleep 2
        done
        if [ "$READY" -ne 1 ]; then
            echo "PREFLIGHT FAILED: $LANG"
            for C in "${LEVELS[@]}"; do
                record_result "$PROFILE" "$LANG" "$C" 0 0 0 PREFLIGHT_FAILED
            done
            docker logs --tail 500 "$API" > "$DIR/logs.txt" 2>&1 || true
            docker rm -f "$API" >/dev/null 2>&1 || true
            CURRENT_API=""
            continue
        fi

        echo "Warm-up: ${WARMUP}s at concurrency 50"
        timeout 90 docker run --rm --network "$NETWORK" "$RUNNER" \
            -url "http://${SRC}:8080/parent/50000" \
            -concurrency 50 -duration "${WARMUP}s" \
            > "$DIR/warmup.txt" 2>&1 || true
        echo "Warmup errors: $(awk '/^Errors:/ {print $2}' "$DIR/warmup.txt" | tail -1)"

        # IMPORTANT: Never stop at the first measurement failure.
        for C in "${LEVELS[@]}"; do
            if [ "$(docker inspect "$API" --format '{{.State.Running}}' 2>/dev/null)" != true ]; then
                echo "Restarting crashed $LANG before concurrency $C (prior failure retained)"
                docker start "$API" >> "$DIR/restarts.txt" 2>&1 || true
                sleep 5
            fi
            RESULT="$DIR/c${C}.txt"
            echo "Testing $LANG at concurrency $C for ${DURATION}s"
            timeout 90 docker run --rm --network "$NETWORK" "$RUNNER" \
                -url "http://${SRC}:8080/parent/50000" \
                -concurrency "$C" -duration "${DURATION}s" \
                > "$RESULT" 2>&1
            RC=$?
            REQUESTS=$(awk '/^Requests:/ {print $2}' "$RESULT" | tail -1)
            ERRORS=$(awk '/^Errors:/ {print $2}' "$RESULT" | tail -1)
            RPS=$(awk '/^Requests\/sec:/ {print $2}' "$RESULT" | tail -1)
            STATUS=PASS
            if [ "$RC" -ne 0 ] || [ "${ERRORS:-none}" != 0 ] ||
               ! [[ "${REQUESTS:-}" =~ ^[0-9]+$ ]] || [ "${REQUESTS:-0}" -eq 0 ]; then
                STATUS=FAILED
            fi
            record_result "$PROFILE" "$LANG" "$C" "${REQUESTS:-0}" "${ERRORS:-unknown}" "${RPS:-0}" "$STATUS"
            echo "$PROFILE $LANG c$C: $STATUS; rps=${RPS:-0}; errors=${ERRORS:-unknown}"
            # Full result appears in foreground log AND in the per-level text file.
            cat "$RESULT"
            docker inspect "$API" \
                --format 'Status={{.State.Status}} OOM={{.State.OOMKilled}} RestartCount={{.RestartCount}}' \
                > "$DIR/c${C}_state.txt" 2>&1 || true
            docker stats --no-stream "$API" "$DB_CLONE" \
                > "$DIR/c${C}_stats.txt" 2>&1 || true
            sleep "$COOLDOWN"
        done
        docker logs --tail 3000 "$API" > "$DIR/logs.txt" 2>&1 || true
        docker rm -f "$API" >/dev/null 2>&1 || true
        CURRENT_API=""
        echo "Completed $PROFILE/$LANG"
    done

    docker logs --tail 3000 "$DB_CLONE" > "$OUT/${PROFILE}_database_log.txt" 2>&1 || true
    docker rm -f "$DB_CLONE" >/dev/null 2>&1 || true
    CURRENT_DB=""
done

echo
printf 'COMPLETED=%s\nFAILED_LEVELS=%s\nRESULTS=%s\n' "$(date -u --iso-8601=seconds)" "$FAILURES" "$OUT" | tee "$OUT/completion.txt"
if [ "$FAILURES" -gt 0 ]; then
    echo 'Failures are retained as valid observations, not overwritten.'
fi
