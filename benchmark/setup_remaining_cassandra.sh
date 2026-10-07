#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

for lang in nim v zig haskell
do
  echo
  echo "=================================================="
  echo "BUILDING ${lang^^} + CASSANDRA"
  echo "=================================================="

  docker build \
    -t "benchmark-${lang}-cassandra-api" \
    "api/${lang}-cassandra"
done

for lang in nim v zig haskell
do
  docker rm -f \
    "benchmark_${lang}_cassandra" \
    2>/dev/null || true

  docker run -d \
    --name "benchmark_${lang}_cassandra" \
    --network api_benchmark_network \
    --cpus 2 \
    --memory 2g \
    --memory-swap 2g \
    -e CASSANDRA_HOST=benchmark_cassandra \
    "benchmark-${lang}-cassandra-api"
done

sleep 5

docker ps -a \
  --filter name=benchmark_nim_cassandra \
  --filter name=benchmark_v_cassandra \
  --filter name=benchmark_zig_cassandra \
  --filter name=benchmark_haskell_cassandra \
  --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}'
