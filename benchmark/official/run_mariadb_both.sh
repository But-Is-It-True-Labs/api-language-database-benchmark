#!/usr/bin/env bash
set -uo pipefail

LANGS=(go rust node python php cpp java elixir ruby csharp v nim zig)
LEVELS=(1 10 50 100 250 500 1000)
PROFILES=(limited unlimited)

DB="benchmark_mariadb"
NETWORK="api_benchmark_network"
RUNNER="api-benchmark-runner"
DURATION=30
WARMUP=30
COOLDOWN=15

STAMP=$(date -u +%Y%m%d_%H%M%S)
OUT="benchmark/results/mariadb_official_${STAMP}"
mkdir -p "$OUT"

# Prevent two official MariaDB runs from overlapping.
exec 9>benchmark/results/mariadb_official.lock
if ! flock -n 9; then
    echo "ERROR: Another official MariaDB run is active."
    exit 1
fi

FAILURES=0
CURRENT=""
SUMMARY="$OUT/summary.csv"
echo "profile,language,concurrency,requests,errors,rps,status" > "$SUMMARY"

cleanup() {
    if [ -n "$CURRENT" ]; then
        docker stop "$CURRENT" >/dev/null 2>&1 || true
    fi
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

echo "OFFICIAL MARIADB BENCHMARK"
echo "Started: $(date -u)"
echo "Results: $OUT"

{
    date -u
    uname -a
    lscpu
    free -h
    docker version
    git rev-parse HEAD 2>/dev/null || true
    git status --short 2>/dev/null || true
} > "$OUT/environment.txt" 2>&1

# Stop other benchmark containers, without deleting them.
echo "Stopping unrelated benchmark containers..."
while IFS= read -r name; do
    [ -n "$name" ] || continue
    [ "$name" = "$DB" ] && continue
    docker stop "$name" >/dev/null 2>&1 || true
done < <(docker ps --format '{{.Names}}' | grep '^benchmark_' || true)

docker start "$DB" >/dev/null 2>&1 || true

# MariaDB must be ready.
READY=0
for i in $(seq 1 60); do
    HEALTH=$(docker inspect "$DB" \
        --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' \
        2>/dev/null || true)
    if [ "$HEALTH" = "healthy" ] || [ "$HEALTH" = "running" ]; then
        READY=1
        break
    fi
    sleep 2
done

if [ "$READY" -ne 1 ]; then
    echo "ERROR: MariaDB is not ready."
    exit 1
fi

# Confirm our previously configured connection limit.
CONNECTION_LIMIT=$(docker exec "$DB" sh -c \
    'MYSQL_PWD="$MARIADB_PASSWORD" mariadb -u benchmark -Nse "SELECT @@GLOBAL.max_connections"' \
    2>/dev/null || true)

echo "MariaDB max_connections=$CONNECTION_LIMIT"

if ! [[ "$CONNECTION_LIMIT" =~ ^[0-9]+$ ]] ||
   [ "$CONNECTION_LIMIT" -lt 2000 ]; then
    echo "ERROR: MariaDB max_connections must be at least 2000."
    exit 1
fi

for PROFILE in "${PROFILES[@]}"; do
    echo
    echo "=========================================="
    echo "PROFILE: $PROFILE"
    echo "=========================================="

    if [ "$PROFILE" = "limited" ]; then
        docker update --cpus 4 --memory 8g \
            --memory-swap 8g "$DB" >/dev/null || exit 1
    else
        docker update --cpus 0 --memory 0 \
            --memory-swap -1 "$DB" >/dev/null || exit 1
    fi

    docker inspect "$DB" \
        --format 'CPU_NANO={{.HostConfig.NanoCpus}} MEMORY={{.HostConfig.Memory}} SWAP={{.HostConfig.MemorySwap}}' \
        | tee "$OUT/${PROFILE}_database_limits.txt"

    if [ "$PROFILE" = "unlimited" ]; then
        LIMITS=$(docker inspect "$DB" \
            --format '{{.HostConfig.NanoCpus}} {{.HostConfig.Memory}}')
        if [ "$LIMITS" != "0 0" ]; then
            echo "ERROR: Database still has resource limits."
            exit 1
        fi
    fi

    for LANG in "${LANGS[@]}"; do
        CT="benchmark_${LANG}_mariadb"
        DIR="$OUT/$PROFILE/$LANG"
        mkdir -p "$DIR"

        echo
        echo "========== $PROFILE / $LANG =========="

        if ! docker container inspect "$CT" >/dev/null 2>&1; then
            echo "MISSING CONTAINER: $CT"
            echo "$PROFILE,$LANG,0,0,0,0,MISSING" >> "$SUMMARY"
            FAILURES=$((FAILURES+1))
            continue
        fi

        CURRENT="$CT"

        if [ "$PROFILE" = "limited" ]; then
            if ! docker update --cpus 2 --memory 2g \
                 --memory-swap 2g "$CT" >/dev/null; then
                echo "RESOURCE CONFIGURATION FAILED: $LANG"
                FAILURES=$((FAILURES+1))
                CURRENT=""
                continue
            fi
        else
            if ! docker update --cpus 0 --memory 0 \
                 --memory-swap -1 "$CT" >/dev/null; then
                echo "RESOURCE CONFIGURATION FAILED: $LANG"
                FAILURES=$((FAILURES+1))
                CURRENT=""
                continue
            fi

            LIMITS=$(docker inspect "$CT" \
                --format '{{.HostConfig.NanoCpus}} {{.HostConfig.Memory}}')
            if [ "$LIMITS" != "0 0" ]; then
                echo "ERROR: $LANG still has resource limits."
                FAILURES=$((FAILURES+1))
                CURRENT=""
                continue
            fi
        fi

        docker inspect "$CT" \
            --format 'IMAGE={{.Image}} CPU_NANO={{.HostConfig.NanoCpus}} MEMORY={{.HostConfig.Memory}} SWAP={{.HostConfig.MemorySwap}}' \
            > "$DIR/resources.txt"

        if ! docker start "$CT" > "$DIR/start.log" 2>&1; then
            echo "START FAILED: $LANG"
            echo "$PROFILE,$LANG,0,0,0,0,START_FAILED" >> "$SUMMARY"
            FAILURES=$((FAILURES+1))
            CURRENT=""
            continue
        fi

        # Wait for the real benchmark endpoint, not just a running process.
        READY=0
        for i in $(seq 1 30); do
            if docker run --rm --network "$NETWORK" \
                curlimages/curl:8.12.1 -fsS \
                --connect-timeout 2 --max-time 5 \
                "http://${CT}:8080/parent/50000" \
                > "$DIR/preflight.json" 2>/dev/null; then
                READY=1
                break
            fi
            sleep 2
        done

        if [ "$READY" -ne 1 ] ||
           ! python3 - "$DIR/preflight.json" <<'PY'
import json, sys
with open(sys.argv[1]) as f:
    row = json.load(f)
assert row["id"] == 50000
assert all(k in row for k in
    ("account_number", "status", "created_at", "payload"))
PY
        then
            echo "PREFLIGHT FAILED: $LANG"
            echo "$PROFILE,$LANG,0,0,0,0,PREFLIGHT_FAILED" >> "$SUMMARY"
            FAILURES=$((FAILURES+1))
            docker logs --tail 100 "$CT" > "$DIR/logs.txt" 2>&1
            docker stop "$CT" >/dev/null 2>&1 || true
            CURRENT=""
            continue
        fi

        echo "Warming up $LANG for ${WARMUP}s..."
        docker run --rm --network "$NETWORK" "$RUNNER" \
            -url "http://${CT}:8080/parent/50000" \
            -concurrency 50 -duration "${WARMUP}s" \
            > "$DIR/warmup.txt" 2>&1

        WARM_ERRORS=$(awk '/^Errors:/ {print $2}' "$DIR/warmup.txt" | tail -1)
        WARM_REQUESTS=$(awk '/^Requests:/ {print $2}' "$DIR/warmup.txt" | tail -1)

        if [ "$WARM_ERRORS" != "0" ] ||
           ! [[ "$WARM_REQUESTS" =~ ^[0-9]+$ ]] ||
           [ "$WARM_REQUESTS" -eq 0 ]; then
            echo "WARMUP FAILED: $LANG"
            cat "$DIR/warmup.txt"
            echo "$PROFILE,$LANG,0,0,${WARM_ERRORS:-unknown},0,WARMUP_FAILED" >> "$SUMMARY"
            FAILURES=$((FAILURES+1))
            docker logs --tail 100 "$CT" > "$DIR/logs.txt" 2>&1
            docker stop "$CT" >/dev/null 2>&1 || true
            CURRENT=""
            continue
        fi

        for C in "${LEVELS[@]}"; do
            echo "Testing $LANG / $PROFILE / concurrency $C"

            RESULT="$DIR/c${C}.txt"

            docker run --rm --network "$NETWORK" "$RUNNER" \
                -url "http://${CT}:8080/parent/50000" \
                -concurrency "$C" -duration "${DURATION}s" \
                > "$RESULT" 2>&1
            RC=$?

            REQUESTS=$(awk '/^Requests:/ {print $2}' "$RESULT" | tail -1)
            ERRORS=$(awk '/^Errors:/ {print $2}' "$RESULT" | tail -1)
            RPS=$(awk '/^Requests\/sec:/ {print $2}' "$RESULT" | tail -1)

            STATUS="PASS"
            if [ "$RC" -ne 0 ] ||
               [ "$ERRORS" != "0" ] ||
               ! [[ "$REQUESTS" =~ ^[0-9]+$ ]] ||
               [ "$REQUESTS" -eq 0 ]; then
                STATUS="FAILED"
                FAILURES=$((FAILURES+1))
            fi

            echo "$PROFILE,$LANG,$C,${REQUESTS:-0},${ERRORS:-unknown},${RPS:-0},$STATUS" \
                >> "$SUMMARY"

            echo "$LANG C=$C: $STATUS - ${RPS:-0} req/sec, ${ERRORS:-unknown} errors"

            docker inspect "$CT" \
                --format 'STATUS={{.State.Status}} OOM={{.State.OOMKilled}} RESTARTS={{.RestartCount}}' \
                > "$DIR/c${C}_state.txt" 2>&1 || true

            docker stats --no-stream "$CT" "$DB" \
                > "$DIR/c${C}_stats.txt" 2>&1 || true

            if [ "$STATUS" = "FAILED" ]; then
                echo "Stopping remaining levels for $LANG due to failure."
                break
            fi

            sleep "$COOLDOWN"
        done

        docker logs --tail 200 "$CT" \
            > "$DIR/logs.txt" 2>&1 || true

        docker stop "$CT" >/dev/null 2>&1 || true
        CURRENT=""
    done
done

echo
echo "=========================================="
echo "OFFICIAL MARIADB RUN COMPLETE"
echo "=========================================="
echo "Finished: $(date -u)"
echo "Failures: $FAILURES"
echo "Results: $OUT"
echo "Summary: $SUMMARY"

if [ "$FAILURES" -gt 0 ]; then
    echo "Some results failed validation. Do not publish them as official."
    exit 1
fi

echo "All official measurements completed without reported request errors."
exit 0
