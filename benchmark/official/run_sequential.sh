#!/usr/bin/env bash

set -u
set -o pipefail

DB="${1:?Usage: $0 cassandra|postgres limited|full}"
MODE="${2:?Usage: $0 cassandra|postgres limited|full}"

NETWORK="api_benchmark_network"
RUNNER="api-benchmark-runner"

DURATION=30
SETTLE=15
COOLDOWN=15

LEVELS=(1 10 50 100 250 500 1000)

LANGS=(
  go
  rust
  node
  python
  php
  cpp
  java
  elixir
  ruby
  haskell
  v
  nim
  zig
)

case "$DB" in
  cassandra)
    DB_CONTAINER="benchmark_cassandra"
    ;;
  postgres)
    DB_CONTAINER="benchmark_postgres"
    ;;
  *)
    echo "Unknown database: $DB"
    exit 1
    ;;
esac

case "$MODE" in
  limited)
    API_CPUS="2"
    API_MEMORY="2g"
    DB_CPUS="4"
    DB_MEMORY="8g"
    ;;
  full)
    API_CPUS="12"
    API_MEMORY="90g"
    DB_CPUS="12"
    DB_MEMORY="90g"
    ;;
  *)
    echo "Unknown mode: $MODE"
    exit 1
    ;;
esac

STAMP=$(date -u +"%Y%m%d_%H%M%S")
OUT="benchmark/results/${DB}_${MODE}_sequential/run_${STAMP}"

mkdir -p "$OUT"

CURRENT_CONTAINER=""

cleanup() {
  if [ -n "$CURRENT_CONTAINER" ]; then
    docker stop "$CURRENT_CONTAINER" >/dev/null 2>&1 || true
  fi
}

trap cleanup EXIT INT TERM


echo "=========================================================="
echo "${DB^^} ${MODE^^} SEQUENTIAL BENCHMARK"
echo "=========================================================="
echo "UTC start: $(date -u)"
echo "Output: $OUT"
echo


###############################################################################
# RECORD ENVIRONMENT
###############################################################################

{
  echo "DATABASE=$DB"
  echo "MODE=$MODE"
  echo "UTC_START=$(date -u)"
  echo "API_CPUS=$API_CPUS"
  echo "API_MEMORY=$API_MEMORY"
  echo "DB_CPUS=$DB_CPUS"
  echo "DB_MEMORY=$DB_MEMORY"
  echo
  uname -a
  echo
  lscpu
  echo
  free -h
  echo
  docker version
} > "$OUT/environment.txt" 2>&1


###############################################################################
# STOP EVERY BENCHMARK CONTAINER EXCEPT CURRENT DATABASE
###############################################################################

echo "Stopping unrelated benchmark containers..."

docker ps --format '{{.Names}}' \
  | grep '^benchmark_' \
  | grep -v "^${DB_CONTAINER}$" \
  | xargs -r docker stop \
  >/dev/null 2>&1 || true


###############################################################################
# CONFIGURE DATABASE
###############################################################################

echo "Configuring $DB_CONTAINER..."

docker update \
  --cpus "$DB_CPUS" \
  --memory "$DB_MEMORY" \
  --memory-swap "$DB_MEMORY" \
  "$DB_CONTAINER" >/dev/null

docker start "$DB_CONTAINER" >/dev/null


###############################################################################
# WAIT FOR DATABASE
###############################################################################

echo "Waiting for database health..."

for i in $(seq 1 90)
do
  HEALTH=$(
    docker inspect "$DB_CONTAINER" \
      --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' \
      2>/dev/null || true
  )

  if [ "$HEALTH" = "healthy" ] || [ "$HEALTH" = "running" ]; then
    echo "$DB_CONTAINER ready: $HEALTH"
    break
  fi

  if [ "$i" -eq 90 ]; then
    echo "ERROR: $DB_CONTAINER did not become ready."
    exit 1
  fi

  sleep 2
done

sleep 10

docker inspect "$DB_CONTAINER" \
  --format 'Name={{.Name}} CPUs={{.HostConfig.NanoCpus}} Memory={{.HostConfig.Memory}} Swap={{.HostConfig.MemorySwap}} Status={{.State.Status}}' \
  > "$OUT/database_resources.txt"


###############################################################################
# RUN LANGUAGES ONE AT A TIME
###############################################################################

for LANG in "${LANGS[@]}"
do
  CONTAINER="benchmark_${LANG}_${DB}"
  URL="http://${CONTAINER}:8080/parent/50000"
  DIR="$OUT/$LANG"

  mkdir -p "$DIR"

  echo
  echo "=========================================================="
  echo "${LANG^^} + ${DB^^} ${MODE^^}"
  echo "=========================================================="

  CURRENT_CONTAINER="$CONTAINER"


  ###########################################################################
  # ENSURE EVERY OTHER LANGUAGE API IS OFF
  ###########################################################################

  for OTHER in "${LANGS[@]}"
  do
    OTHER_CONTAINER="benchmark_${OTHER}_${DB}"

    if [ "$OTHER_CONTAINER" != "$CONTAINER" ]; then
      docker stop "$OTHER_CONTAINER" >/dev/null 2>&1 || true
    fi
  done


  ###########################################################################
  # APPLY RESOURCE PROFILE
  ###########################################################################

  docker update \
    --cpus "$API_CPUS" \
    --memory "$API_MEMORY" \
    --memory-swap "$API_MEMORY" \
    "$CONTAINER" >/dev/null


  ###########################################################################
  # START API
  ###########################################################################

  docker start "$CONTAINER" > "$DIR/start.txt" 2>&1

  echo "Waiting ${SETTLE}s..."
  sleep "$SETTLE"

  docker inspect "$CONTAINER" \
    --format 'Name={{.Name}} CPUs={{.HostConfig.NanoCpus}} Memory={{.HostConfig.Memory}} Swap={{.HostConfig.MemorySwap}} Status={{.State.Status}} OOMKilled={{.State.OOMKilled}} RestartCount={{.RestartCount}}' \
    > "$DIR/resources_before.txt"


  ###########################################################################
  # SMOKE TEST
  ###########################################################################

  echo "Smoke testing $LANG..."

  if ! docker run --rm \
      --network "$NETWORK" \
      curlimages/curl:8.12.1 \
      -fsS \
      --connect-timeout 5 \
      --max-time 10 \
      "$URL" \
      > "$DIR/smoke.json"
  then
    echo "SMOKE TEST FAILED: $LANG" | tee "$DIR/FAILED.txt"

    docker logs --tail 200 "$CONTAINER" \
      > "$DIR/container_logs.txt" 2>&1 || true

    docker stop "$CONTAINER" >/dev/null 2>&1 || true
    CURRENT_CONTAINER=""
    continue
  fi

  echo "Smoke test passed."


  ###########################################################################
  # TEST ALL CONCURRENCY LEVELS
  ###########################################################################

  for C in "${LEVELS[@]}"
  do
    RESULT="$DIR/c${C}.txt"

    echo
    echo "----------------------------------------------------------"
    echo "${LANG^^}: concurrency $C"
    echo "----------------------------------------------------------"

    {
      echo "========================================"
      echo "${LANG^^} + ${DB^^} ${MODE^^} OFFICIAL"
      echo "========================================"
      echo "UTC:"
      date -u
      echo
    } > "$RESULT"

    docker run --rm \
      --network "$NETWORK" \
      "$RUNNER" \
      -url "$URL" \
      -concurrency "$C" \
      -duration "${DURATION}s" \
      >> "$RESULT" 2>&1

    RC=$?

    cat "$RESULT"

    echo "$RC" > "$DIR/c${C}_exit_code.txt"

    docker inspect "$CONTAINER" \
      --format 'Status={{.State.Status}} ExitCode={{.State.ExitCode}} OOMKilled={{.State.OOMKilled}} RestartCount={{.RestartCount}}' \
      > "$DIR/c${C}_container_state.txt"

    docker stats --no-stream \
      "$CONTAINER" "$DB_CONTAINER" \
      > "$DIR/c${C}_stats_after.txt" 2>&1 || true

    echo
    echo "Cooling down ${COOLDOWN}s..."
    sleep "$COOLDOWN"
  done


  ###########################################################################
  # STOP CURRENT API BEFORE NEXT LANGUAGE
  ###########################################################################

  docker logs --tail 200 "$CONTAINER" \
    > "$DIR/container_logs_after.txt" 2>&1 || true

  echo "Stopping $CONTAINER..."

  docker stop "$CONTAINER" >/dev/null 2>&1 || true

  CURRENT_CONTAINER=""

  echo "Completed $LANG."
done


###############################################################################
# GENERATE SUMMARY
###############################################################################

SUMMARY="$OUT/summary.txt"

{
  echo "=========================================================="
  echo "${DB^^} ${MODE^^} SEQUENTIAL SUMMARY"
  echo "=========================================================="

  for LANG in "${LANGS[@]}"
  do
    echo
    echo "================ ${LANG^^} ================"

    for C in "${LEVELS[@]}"
    do
      RESULT="$OUT/$LANG/c${C}.txt"

      echo
      echo "C=$C"

      if [ -f "$RESULT" ]; then
        grep -E \
          'Requests:|Errors:|Requests/sec:|Average:|p50:|p95:|p99:|Max:' \
          "$RESULT" || true
      else
        echo "NO RESULT"
      fi
    done
  done

  echo
  echo "UTC_FINISH=$(date -u)"
} > "$SUMMARY"

echo
echo "=========================================================="
echo "${DB^^} ${MODE^^} COMPLETE"
echo "=========================================================="
echo "Results: $OUT"
echo "Summary: $SUMMARY"
echo
