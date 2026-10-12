#!/usr/bin/env bash
set -uo pipefail

cd "$(dirname "$0")/../.."

exec 9>benchmark/results/five_database_campaign.lock
if ! flock -n 9; then
    echo "ERROR: Another five-database campaign is running."
    exit 1
fi

NETWORK="api_benchmark_network"
RUNNER="api-benchmark-runner"

DATABASES=(postgres mariadb cassandra yugabyte mongodb)
MODES=(limited full)
LANGS=(go rust node python php cpp java elixir ruby v nim zig)
LEVELS=(1 10 50 100 250 500 1000)

DURATION=30
API_SETTLE=15
COOLDOWN=15
DB_STABILIZE=180

STAMP=$(date -u +%Y%m%d_%H%M%S)
OUT="benchmark/results/five_database_campaign_$STAMP"
mkdir -p "$OUT"

echo "$OUT" > benchmark/results/five_database_campaign_latest.txt

SUMMARY="$OUT/summary.tsv"
printf 'Mode\tDatabase\tLanguage\tConcurrency\tRequests\tRPS\tErrors\tStatus\n' > "$SUMMARY"

CURRENT_API=""

cleanup() {
    if [ -n "$CURRENT_API" ]; then
        docker stop "$CURRENT_API" >/dev/null 2>&1 || true
    fi
}
trap cleanup EXIT

{
    echo "UTC START: $(date -u)"
    echo "Git commit: $(git rev-parse HEAD 2>/dev/null || true)"
    echo "Concurrency: ${LEVELS[*]}"
    echo "Duration: ${DURATION}s"
    echo "API settle: ${API_SETTLE}s"
    echo "Cooldown: ${COOLDOWN}s"
    echo "Database stabilization: ${DB_STABILIZE}s"
    echo
    uname -a
    nproc
    free -h
    docker version
} > "$OUT/environment.txt" 2>&1

echo "========================================"
echo "BUT IS IT TRUE? - OFFICIAL CAMPAIGN"
echo "FIVE DATABASES - LIMITED AND FULL"
echo "========================================"
echo "Results: $OUT"

for MODE in "${MODES[@]}"; do

    if [ "$MODE" = "limited" ]; then
        API_CPUS=2
        API_MEMORY=2g
        DB_CPUS=4
        DB_MEMORY=8g
    else
        API_CPUS=12
        API_MEMORY=90g
        DB_CPUS=12
        DB_MEMORY=90g
    fi

    for DB in "${DATABASES[@]}"; do

        DB_CONTAINER="benchmark_${DB}"
        DB_DIR="$OUT/$MODE/$DB"
        mkdir -p "$DB_DIR"

        echo
        echo "========================================"
        echo "$MODE / $DB"
        echo "========================================"
        echo "UTC: $(date -u)"

        # Stop every benchmark API and database.
        # Never delete containers or volumes.
        echo "Stopping other benchmark containers..."

        docker ps --format '{{.Names}}' |
            grep '^benchmark_' |
            xargs -r docker stop >/dev/null 2>&1 || true

        if ! docker inspect "$DB_CONTAINER" >/dev/null 2>&1; then
            echo "DATABASE MISSING: $DB_CONTAINER"
            echo "MISSING_DATABASE" > "$DB_DIR/FAILED.txt"
            continue
        fi

        echo "Applying database resource limits..."

        if ! docker update \
            --cpus "$DB_CPUS" \
            --memory "$DB_MEMORY" \
            --memory-swap "$DB_MEMORY" \
            "$DB_CONTAINER" > "$DB_DIR/update.log" 2>&1; then
            echo "DATABASE RESOURCE CONFIGURATION FAILED"
            cat "$DB_DIR/update.log"
            continue
        fi

        if ! docker start "$DB_CONTAINER" > "$DB_DIR/start.log" 2>&1; then
            echo "DATABASE START FAILED"
            cat "$DB_DIR/start.log"
            continue
        fi

        echo "Waiting for database health (up to 10 minutes)..."

        DB_READY=0

        for i in $(seq 1 120); do
            HEALTH=$(docker inspect "$DB_CONTAINER" \
                --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' \
                2>/dev/null || true)

            if [ "$HEALTH" = "healthy" ] || [ "$HEALTH" = "running" ]; then
                DB_READY=1
                break
            fi

            sleep 5
        done

        if [ "$DB_READY" -ne 1 ]; then
            echo "DATABASE HEALTH FAILED: $DB"
            docker logs --tail 100 "$DB_CONTAINER" \
                > "$DB_DIR/database_failure.log" 2>&1 || true
            continue
        fi

        echo "Database ready: $HEALTH"
        echo "Stabilizing for 180 seconds..."
        sleep "$DB_STABILIZE"

        docker inspect "$DB_CONTAINER" \
            --format 'Image={{.Image}} CPUs={{.HostConfig.NanoCpus}} Memory={{.HostConfig.Memory}} Swap={{.HostConfig.MemorySwap}}' \
            > "$DB_DIR/database_resources.txt"

        THIS_LANGS=("${LANGS[@]}")

        # C# exists only for these three databases.
        case "$DB" in
            mariadb|yugabyte|mongodb)
                THIS_LANGS+=(csharp)
                ;;
        esac

        for LANG in "${THIS_LANGS[@]}"; do

            CT="benchmark_${LANG}_${DB}"
            URL="http://${CT}:8080/parent/50000"
            DIR="$DB_DIR/$LANG"
            mkdir -p "$DIR"

            echo
            echo "########################################"
            echo "$MODE / $DB / $LANG"
            echo "########################################"

            if ! docker inspect "$CT" >/dev/null 2>&1; then
                echo "MISSING API: $CT"
                printf '%s\t%s\t%s\t-\t0\t0\t-\tMISSING\n' \
                    "$MODE" "$DB" "$LANG" >> "$SUMMARY"
                continue
            fi

            if ! docker update \
                --cpus "$API_CPUS" \
                --memory "$API_MEMORY" \
                --memory-swap "$API_MEMORY" \
                "$CT" > "$DIR/update.log" 2>&1; then

                echo "API RESOURCE CONFIGURATION FAILED"
                printf '%s\t%s\t%s\t-\t0\t0\t-\tCONFIG_FAILED\n' \
                    "$MODE" "$DB" "$LANG" >> "$SUMMARY"
                continue
            fi

            docker inspect "$CT" \
                --format 'Image={{.Image}} CPUs={{.HostConfig.NanoCpus}} Memory={{.HostConfig.Memory}} Swap={{.HostConfig.MemorySwap}}' \
                > "$DIR/resources.txt"

            if ! docker start "$CT" > "$DIR/start.log" 2>&1; then
                echo "API START FAILED"
                printf '%s\t%s\t%s\t-\t0\t0\t-\tSTART_FAILED\n' \
                    "$MODE" "$DB" "$LANG" >> "$SUMMARY"
                continue
            fi

            CURRENT_API="$CT"

            API_READY=0

            for i in $(seq 1 60); do
                if docker run --rm \
                    --network "$NETWORK" \
                    curlimages/curl:8.12.1 \
                    -fsS --connect-timeout 3 --max-time 10 \
                    "$URL" > "$DIR/preflight.json" 2>/dev/null; then

                    if python3 - "$DIR/preflight.json" <<'PY'
import json, sys
with open(sys.argv[1]) as f:
    p = json.load(f)
assert int(p["id"]) == 50000
assert all(k in p for k in ("account_number", "status", "created_at", "payload"))
PY
                    then
                        API_READY=1
                        break
                    fi
                fi
                sleep 2
            done

            if [ "$API_READY" -ne 1 ]; then
                echo "API PREFLIGHT FAILED"
                printf '%s\t%s\t%s\t-\t0\t0\t-\tPREFLIGHT_FAILED\n' \
                    "$MODE" "$DB" "$LANG" >> "$SUMMARY"

                docker logs --tail 200 "$CT" \
                    > "$DIR/container_logs.txt" 2>&1 || true
                docker stop "$CT" >/dev/null 2>&1 || true
                CURRENT_API=""
                continue
            fi

            echo "API ready. Settling ${API_SETTLE}s..."
            sleep "$API_SETTLE"

            for C in "${LEVELS[@]}"; do
                LOG="$DIR/c${C}.txt"

                echo
                echo "========================================"
                echo "$MODE / $DB / $LANG / C$C"
                echo "========================================"

                {
                    echo "========================================"
                    echo "$MODE / $DB / $LANG / C$C"
                    echo "UTC: $(date -u)"
                    echo "========================================"
                } > "$LOG"

                docker run --rm \
                    --network "$NETWORK" \
                    "$RUNNER" \
                    -url "$URL" \
                    -concurrency "$C" \
                    -duration "${DURATION}s" \
                    >> "$LOG" 2>&1

                RC=$?

                # Print the original full benchmark output.
                cat "$LOG"

                REQUESTS=$(awk '$1=="Requests:"{print $2}' "$LOG" | tail -1)
                RPS=$(awk '$1=="Requests/sec:"{print $2}' "$LOG" | tail -1)
                ERRORS=$(awk '$1=="Errors:"{print $2}' "$LOG" | tail -1)

                STATUS="PASS"

                if [ "$RC" -ne 0 ] ||
                   ! [[ "${REQUESTS:-}" =~ ^[0-9]+$ ]] ||
                   [ "${REQUESTS:-0}" -eq 0 ] ||
                   [ "${ERRORS:-missing}" != "0" ]; then
                    STATUS="FAIL"
                fi

                printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
                    "$MODE" "$DB" "$LANG" "$C" \
                    "${REQUESTS:-0}" "${RPS:-0}" \
                    "${ERRORS:-unknown}" "$STATUS" \
                    >> "$SUMMARY"

                echo "RESULT: $MODE / $DB / $LANG / C$C = $STATUS"

                docker stats --no-stream "$CT" "$DB_CONTAINER" \
                    > "$DIR/c${C}_stats.txt" 2>&1 || true

                sleep "$COOLDOWN"
            done

            docker logs --tail 200 "$CT" \
                > "$DIR/container_logs.txt" 2>&1 || true

            docker stop "$CT" >/dev/null 2>&1 || true
            CURRENT_API=""

            echo "COMPLETED: $MODE / $DB / $LANG"
        done

        echo
        echo "DATABASE GROUP COMPLETE: $MODE / $DB"
        echo "UTC: $(date -u)"

        docker stop "$DB_CONTAINER" >/dev/null 2>&1 || true
    done
done

echo
echo "========================================"
echo "ALL DATABASE CAMPAIGN TESTS COMPLETED"
echo "========================================"

echo "UTC FINISH: $(date -u)"
echo "Results: $OUT"

echo "PASS: $(awk -F '\t' '$8=="PASS"{n++} END{print n+0}' "$SUMMARY")"
echo "FAIL: $(awk -F '\t' '$8=="FAIL"{n++} END{print n+0}' "$SUMMARY")"
echo "Summary: $SUMMARY"

echo "COMPLETE"
