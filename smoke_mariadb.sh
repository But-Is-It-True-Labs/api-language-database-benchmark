#!/usr/bin/env bash

LANGS=(go rust node python php cpp java elixir ruby csharp v nim zig)
NETWORK="api_benchmark_network"
RUNNER="api-benchmark-runner"

mkdir -p benchmark/results/smoke

DB_PASS=$(docker inspect benchmark_mariadb \
  --format '{{range .Config.Env}}{{println .}}{{end}}' \
  | sed -n 's/^MARIADB_PASSWORD=//p' | head -1)

if [ -z "$DB_PASS" ]; then
    echo "ERROR: MariaDB password not found."
    exit 1
fi

RESULTS=()
FAILED=()

echo "========================================"
echo "PREPARING ALL 13 MARIADB CONTAINERS"
echo "========================================"

for LANG in "${LANGS[@]}"; do
    CONTAINER="benchmark_${LANG}_mariadb"
    IMAGE="benchmark-${LANG}-mariadb"

    if docker container inspect "$CONTAINER" >/dev/null 2>&1; then
        echo "$LANG: Container exists"
        continue
    fi

    if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
        echo "$LANG: IMAGE MISSING"
        FAILED+=("$LANG: image missing")
        continue
    fi

    if docker create \
        --name "$CONTAINER" \
        --network "$NETWORK" \
        -e MYSQLHOST=benchmark_mariadb \
        -e MYSQLPORT=3306 \
        -e MYSQLUSER=benchmark \
        -e MYSQLPASSWORD="$DB_PASS" \
        -e MYSQLDATABASE=benchmark \
        -e DB_HOST=benchmark_mariadb \
        -e DB_PORT=3306 \
        -e DB_USER=benchmark \
        -e DB_PASSWORD="$DB_PASS" \
        -e DB_NAME=benchmark \
        "$IMAGE" >/dev/null; then

        echo "$LANG: Container created"
    else
        echo "$LANG: CONTAINER CREATION FAILED"
        FAILED+=("$LANG: container creation failed")
    fi
done

unset DB_PASS

echo
echo "========================================"
echo "STOPPING API CONTAINERS FOR CLEAN TESTS"
echo "========================================"

for LANG in "${LANGS[@]}"; do
    CONTAINER="benchmark_${LANG}_mariadb"

    if docker container inspect "$CONTAINER" >/dev/null 2>&1; then
        docker stop "$CONTAINER" >/dev/null 2>&1 || true
    fi
done

echo
echo "========================================"
echo "STARTING 5-SECOND SMOKE TESTS"
echo "========================================"

for LANG in "${LANGS[@]}"; do
    CONTAINER="benchmark_${LANG}_mariadb"
    LOG="benchmark/results/smoke/${LANG}_mariadb.log"

    if ! docker container inspect "$CONTAINER" >/dev/null 2>&1; then
        echo "$LANG: SKIPPED - no container"
        continue
    fi

    echo
    echo "========== TESTING $LANG =========="

    if ! docker start "$CONTAINER" >/dev/null; then
        echo "$LANG: START FAILED"
        FAILED+=("$LANG: start failed")
        docker logs --tail 15 "$CONTAINER" 2>&1
        continue
    fi

    sleep 3

    if [ "$(docker inspect -f '{{.State.Running}}' "$CONTAINER")" != "true" ]; then
        echo "$LANG: CONTAINER CRASHED"
        FAILED+=("$LANG: container crashed")
        docker logs --tail 15 "$CONTAINER" 2>&1
        continue
    fi

    docker run --rm \
        --network "$NETWORK" \
        "$RUNNER" \
        -url "http://${CONTAINER}:8080/parent/50000" \
        -concurrency 50 \
        -duration 5s \
        2>&1 | tee "$LOG"

    RUN_STATUS=${PIPESTATUS[0]}

    ERRORS=$(awk '/^Errors:/ {print $2}' "$LOG" | tail -1)
    REQUESTS=$(awk '/^Requests:/ {print $2}' "$LOG" | tail -1)
    RPS=$(awk '/^Requests\/sec:/ {print $2}' "$LOG" | tail -1)

    if [ "$RUN_STATUS" -eq 0 ] &&
       [ "$ERRORS" = "0" ] &&
       [ "${REQUESTS:-0}" -gt 0 ] 2>/dev/null; then

        echo "$LANG: PASS - $RPS requests/sec"
        RESULTS+=("$LANG: PASS ($RPS req/sec)")
    else
        echo "$LANG: FAILED - ${ERRORS:-unknown} errors"
        FAILED+=("$LANG: test failed (${ERRORS:-unknown} errors)")
        docker logs --tail 20 "$CONTAINER" 2>&1
    fi

    docker stop "$CONTAINER" >/dev/null 2>&1 || true
done

echo
echo "========================================"
echo "FINAL SMOKE TEST RESULTS"
echo "========================================"

printf '%s\n' "${RESULTS[@]}"

echo
echo "FAILED / NEEDS ATTENTION:"
if [ "${#FAILED[@]}" -eq 0 ]; then
    echo "NONE - ALL 13 PASSED"
else
    printf '%s\n' "${FAILED[@]}"
fi

echo
echo "PASSED: ${#RESULTS[@]} / ${#LANGS[@]}"
echo "========================================"
