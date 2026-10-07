#!/usr/bin/env bash

set -u
set -o pipefail

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

declare -A CONTAINERS=(
  [go]="benchmark_go_cassandra"
  [rust]="benchmark_rust_cassandra"
  [node]="benchmark_node_cassandra"
  [python]="benchmark_python_cassandra"
  [php]="benchmark_php_cassandra"
  [cpp]="benchmark_cpp_cassandra"
  [java]="benchmark_java_cassandra"
  [elixir]="benchmark_elixir_cassandra"
  [ruby]="benchmark_ruby_cassandra"
  [haskell]="benchmark_haskell_cassandra"
  [v]="benchmark_v_cassandra"
  [nim]="benchmark_nim_cassandra"
  [zig]="benchmark_zig_cassandra"
)

declare -A URLS=(
  [go]="http://benchmark_go_cassandra:8080/parent/50000"
  [rust]="http://benchmark_rust_cassandra:8080/parent/50000"
  [node]="http://benchmark_node_cassandra:8080/parent/50000"
  [python]="http://benchmark_python_cassandra:8080/parent/50000"
  [php]="http://benchmark_php_cassandra:8080/parent/50000"
  [cpp]="http://benchmark_cpp_cassandra:8080/parent/50000"
  [java]="http://benchmark_java_cassandra:8080/parent/50000"
  [elixir]="http://benchmark_elixir_cassandra:8080/parent/50000"
  [ruby]="http://benchmark_ruby_cassandra:8080/parent/50000"
  [haskell]="http://benchmark_haskell_cassandra:8080/parent/50000"
  [v]="http://benchmark_v_cassandra:8080/parent/50000"
  [nim]="http://benchmark_nim_cassandra:8080/parent/50000"
  [zig]="http://benchmark_zig_cassandra:8080/parent/50000"
)

STAMP=$(date -u +"%Y%m%d_%H%M%S")

OUT="benchmark/results/cassandra_official_sequential/run_${STAMP}"

mkdir -p "$OUT"

CURRENT_CONTAINER=""

cleanup() {
  if [ -n "$CURRENT_CONTAINER" ]; then
    docker stop "$CURRENT_CONTAINER" >/dev/null 2>&1 || true
  fi
}

trap cleanup EXIT INT TERM


echo "=========================================================="
echo "OFFICIAL CASSANDRA SEQUENTIAL LANGUAGE BENCHMARK"
echo "=========================================================="
echo
echo "Results:"
echo "$OUT"
echo


###############################################################################
# SAVE ENVIRONMENT
###############################################################################

{
  echo "UTC START:"
  date -u

  echo
  echo "HOST:"
  uname -a

  echo
  echo "DOCKER:"
  docker version --format '{{.Server.Version}}' 2>/dev/null || true

  echo
  echo "LEVELS:"
  echo "${LEVELS[*]}"

  echo
  echo "DURATION:"
  echo "${DURATION}s"

  echo
  echo "SETTLE:"
  echo "${SETTLE}s"

  echo
  echo "COOLDOWN:"
  echo "${COOLDOWN}s"

} > "$OUT/environment.txt"


###############################################################################
# STOP OTHER BENCHMARK CONTAINERS
###############################################################################

echo "Stopping all benchmark containers except Cassandra..."

docker ps \
  --format '{{.Names}}' \
  | grep '^benchmark_' \
  | grep -v '^benchmark_cassandra$' \
  | xargs -r docker stop \
  >/dev/null


###############################################################################
# STANDARD CASSANDRA RESOURCE LIMIT
###############################################################################

echo "Applying Cassandra standard limits..."

docker update \
  --cpus 4 \
  --memory 8g \
  --memory-swap 8g \
  benchmark_cassandra \
  >/dev/null

docker start benchmark_cassandra \
  >/dev/null


###############################################################################
# WAIT FOR CASSANDRA
###############################################################################

echo "Waiting for Cassandra health..."

for i in $(seq 1 60)
do
  HEALTH=$(
    docker inspect benchmark_cassandra \
      --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' \
      2>/dev/null || true
  )

  if [ "$HEALTH" = "healthy" ]; then
    echo "Cassandra is healthy."
    break
  fi

  if [ "$i" -eq 60 ]; then
    echo "ERROR: Cassandra did not become healthy."
    exit 1
  fi

  sleep 2
done


docker inspect benchmark_cassandra \
  --format 'Name={{.Name}} CPUs={{.HostConfig.NanoCpus}} Memory={{.HostConfig.Memory}} Swap={{.HostConfig.MemorySwap}} Status={{.State.Status}}' \
  > "$OUT/cassandra_resources.txt"


###############################################################################
# RUN EACH LANGUAGE SEQUENTIALLY
###############################################################################

for LANG in "${LANGS[@]}"
do
  CONTAINER="${CONTAINERS[$LANG]}"
  URL="${URLS[$LANG]}"

  DIR="$OUT/$LANG"

  mkdir -p "$DIR"

  echo
  echo "=========================================================="
  echo "${LANG^^} + CASSANDRA"
  echo "=========================================================="

  CURRENT_CONTAINER="$CONTAINER"


  ###########################################################################
  # MAKE SURE NO OTHER API IS RUNNING
  ###########################################################################

  for OTHER_LANG in "${LANGS[@]}"
  do
    OTHER_CONTAINER="${CONTAINERS[$OTHER_LANG]}"

    if [ "$OTHER_CONTAINER" != "$CONTAINER" ]; then
      docker stop "$OTHER_CONTAINER" \
        >/dev/null 2>&1 || true
    fi
  done


  ###########################################################################
  # STANDARD API RESOURCE LIMIT
  ###########################################################################

  docker update \
    --cpus 2 \
    --memory 2g \
    --memory-swap 2g \
    "$CONTAINER" \
    >/dev/null


  ###########################################################################
  # START LANGUAGE
  ###########################################################################

  echo "Starting $CONTAINER..."

  docker start "$CONTAINER" \
    > "$DIR/start.txt" 2>&1

  echo "Waiting ${SETTLE}s..."
  sleep "$SETTLE"


  ###########################################################################
  # RECORD RESOURCE CONFIGURATION
  ###########################################################################

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
      > "$DIR/smoke_parent_50000.json"
  then
    echo "SMOKE TEST FAILED FOR $LANG" \
      | tee "$DIR/FAILED.txt"

    docker logs \
      --tail 100 \
      "$CONTAINER" \
      > "$DIR/container_logs.txt" 2>&1

    docker stop "$CONTAINER" \
      >/dev/null 2>&1 || true

    CURRENT_CONTAINER=""

    continue
  fi

  echo "Smoke test passed."


  ###########################################################################
  # RUN ALL CONCURRENCY LEVELS
  ###########################################################################

  for C in "${LEVELS[@]}"
  do
    echo
    echo "----------------------------------------------------------"
    echo "${LANG^^}: concurrency $C"
    echo "----------------------------------------------------------"

    RESULT="$DIR/c${C}.txt"

    {
      echo "========================================"
      echo "${LANG^^} + CASSANDRA OFFICIAL"
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

    EXIT_CODE=$?

    cat "$RESULT"

    echo "$EXIT_CODE" \
      > "$DIR/c${C}_exit_code.txt"

    docker inspect "$CONTAINER" \
      --format 'Status={{.State.Status}} ExitCode={{.State.ExitCode}} OOMKilled={{.State.OOMKilled}} RestartCount={{.RestartCount}}' \
      > "$DIR/c${C}_container_state.txt"

    if [ "$EXIT_CODE" -ne 0 ]; then
      echo "WARNING: runner exited non-zero for $LANG c${C}"
    fi

    echo
    echo "Cooling down ${COOLDOWN}s..."
    sleep "$COOLDOWN"
  done


  ###########################################################################
  # CAPTURE LOGS AND STOP LANGUAGE
  ###########################################################################

  docker logs \
    --tail 200 \
    "$CONTAINER" \
    > "$DIR/container_logs_after.txt" 2>&1 || true

  docker inspect "$CONTAINER" \
    --format 'Name={{.Name}} Status={{.State.Status}} ExitCode={{.State.ExitCode}} OOMKilled={{.State.OOMKilled}} RestartCount={{.RestartCount}}' \
    > "$DIR/container_state_after.txt"

  echo
  echo "Stopping $CONTAINER..."

  docker stop "$CONTAINER" \
    >/dev/null 2>&1 || true

  CURRENT_CONTAINER=""

  echo "Completed $LANG."
done


###############################################################################
# SUMMARY
###############################################################################

SUMMARY="$OUT/summary.txt"

{
  echo "=========================================================="
  echo "CASSANDRA OFFICIAL SEQUENTIAL SUMMARY"
  echo "=========================================================="
  echo

  for LANG in "${LANGS[@]}"
  do
    echo "================ ${LANG^^} ================"

    for C in "${LEVELS[@]}"
    do
      RESULT="$OUT/$LANG/c${C}.txt"

      echo
      echo "C=$C"

      if [ -f "$RESULT" ]; then
        grep -E \
          'Requests:|Errors:|Requests/sec:|Average:|p50:|p95:|p99:|Max:' \
          "$RESULT" \
          || true
      else
        echo "NO RESULT"
      fi
    done

    echo
  done

  echo
  echo "UTC FINISH:"
  date -u

} > "$SUMMARY"


echo
echo "=========================================================="
echo "ALL 13 CASSANDRA LANGUAGE TESTS COMPLETE"
echo "=========================================================="
echo
echo "Raw results:"
echo "$OUT"
echo
echo "Summary:"
echo "$SUMMARY"
echo

cat "$SUMMARY"
