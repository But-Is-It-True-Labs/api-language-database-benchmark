#!/usr/bin/env bash

set -u
set -o pipefail

cd "$(dirname "$0")/../.."

echo "=========================================================="
echo "STARTING REMAINING OFFICIAL BENCHMARK PIPELINE"
echo "UTC: $(date -u)"
echo "=========================================================="

echo
echo "PHASE 1/3: CASSANDRA FULL"
./benchmark/official/run_sequential.sh cassandra full

echo
echo "Cooling server for 60 seconds between phases..."
sleep 60

echo
echo "PHASE 2/3: POSTGRESQL LIMITED"
./benchmark/official/run_sequential.sh postgres limited

echo
echo "Cooling server for 60 seconds between phases..."
sleep 60

echo
echo "PHASE 3/3: POSTGRESQL FULL"
./benchmark/official/run_sequential.sh postgres full

echo
echo "=========================================================="
echo "ALL THREE PHASES COMPLETE"
echo "UTC: $(date -u)"
echo "=========================================================="
