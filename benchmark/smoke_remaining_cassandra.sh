#!/usr/bin/env bash
set -u

cd "$(dirname "$0")/.."

for lang in nim v zig haskell
do
  echo
  echo "=================================================="
  echo "${lang^^} HEALTH"
  echo "=================================================="

  docker run --rm \
    --network api_benchmark_network \
    curlimages/curl:8.12.1 \
    -sS \
    --connect-timeout 3 \
    --max-time 5 \
    "http://benchmark_${lang}_cassandra:8080/health"

  echo

  echo
  echo "${lang^^} PARENT 50000"

  docker run --rm \
    --network api_benchmark_network \
    curlimages/curl:8.12.1 \
    -sS \
    --connect-timeout 3 \
    --max-time 5 \
    "http://benchmark_${lang}_cassandra:8080/parent/50000"

  echo
done
