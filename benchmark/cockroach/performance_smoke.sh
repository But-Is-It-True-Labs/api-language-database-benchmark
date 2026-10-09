#!/usr/bin/env bash
set -uo pipefail

NETWORK="api_benchmark_network"
RUNNER="api-benchmark-runner"

LANGS=(go rust node python php cpp java elixir ruby haskell v nim zig)

OUT="benchmark/results/cockroach_preflight_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$OUT"

FAILED=()

echo "========================================"
echo "STARTING ALL COCKROACHDB APIS"
echo "========================================"

for LANG in "${LANGS[@]}"; do
    CONTAINER="benchmark_${LANG}_cockroach"

    if [ "$(docker inspect -f '{{.State.Running}}' "$CONTAINER" 2>/dev/null)" != "true" ]; then
        if ! docker start "$CONTAINER"; then
            echo "START FAILED: $LANG"
        fi
    fi
done

sleep 10

echo
echo "========================================"
echo "COCKROACHDB PERFORMANCE SMOKE TEST"
echo "Concurrency: 50"
echo "Duration: 10 seconds per language"
echo "========================================"

for LANG in "${LANGS[@]}"; do
    CONTAINER="benchmark_${LANG}_cockroach"
    URL="http://${CONTAINER}:8080/parent/50000"
    RESULT="$OUT/${LANG}.txt"

    echo
    echo "========================================"
    echo "TESTING ${LANG^^} + COCKROACHDB"
    echo "========================================"

    docker run --rm \
      --network "$NETWORK" \
      "$RUNNER" \
      -url "$URL" \
      -concurrency 50 \
      -duration 10s \
      2>&1 | tee "$RESULT"

    RC=${PIPESTATUS[0]}

    ERRORS=$(awk '/^Errors:/ {print $2}' "$RESULT" | tail -1)
    RPS=$(awk '/^Requests\/sec:/ {print $2}' "$RESULT" | tail -1)

    if [ "$RC" -ne 0 ] || [ -z "$ERRORS" ] || [ "$ERRORS" != "0" ] || [ -z "$RPS" ]; then
        echo "FAILED: $LANG"
        FAILED+=("$LANG")
        docker logs --tail 30 "$CONTAINER" \
          > "$OUT/${LANG}_logs.txt" 2>&1
    else
        echo "PASSED: $LANG"
    fi
done

echo
echo "========================================"
echo "FINAL RESULTS"
echo "========================================"
echo "Total languages: ${#LANGS[@]}"
echo "Passed: $((${#LANGS[@]} - ${#FAILED[@]}))"
echo "Failed: ${#FAILED[@]}"
echo "Failed languages: ${FAILED[*]:-None}"
echo "Results saved: $OUT"

if [ "${#FAILED[@]}" -ne 0 ]; then
    exit 1
fi
