#!/usr/bin/env bash
set -uo pipefail

NETWORK="api_benchmark_network"
DB_CONTAINER="benchmark_cockroach"

LANGS=(
  go rust node python php cpp java elixir ruby haskell v nim zig
)

DB_HOST="benchmark_cockroach"
DB_PORT="26257"
DB_USER="root"
DB_NAME="benchmark"

DATABASE_URL="postgresql://${DB_USER}@${DB_HOST}:${DB_PORT}/${DB_NAME}?sslmode=disable"

FAILED=()

if ! docker inspect "$DB_CONTAINER" >/dev/null 2>&1; then
  echo "ERROR: CockroachDB container does not exist."
  exit 1
fi

if ! docker network inspect "$NETWORK" >/dev/null 2>&1; then
  echo "ERROR: Docker network does not exist."
  exit 1
fi

for LANG in "${LANGS[@]}"; do

  echo
  echo "=========================================================="
  echo "BUILDING ${LANG^^} + COCKROACHDB"
  echo "=========================================================="

  IMAGE="benchmark-${LANG}-cockroach"
  CONTAINER="benchmark_${LANG}_cockroach"
  DIR="./api/${LANG}-cockroach"

  if [ ! -f "$DIR/Dockerfile" ]; then
    echo "MISSING DOCKERFILE: $LANG"
    FAILED+=("$LANG")
    continue
  fi

  if ! docker build -t "$IMAGE" "$DIR"; then
    echo "BUILD FAILED: $LANG"
    FAILED+=("$LANG")
    continue
  fi

  docker rm -f "$CONTAINER" >/dev/null 2>&1 || true

  COMMON=(
    docker create
    --name "$CONTAINER"
    --network "$NETWORK"
  )

  APP_DATABASE_URL="$DATABASE_URL"
  PG_HOST="$DB_HOST"
  if [ "$LANG" = "elixir" ]; then APP_DATABASE_URL="postgresql://root:@cockroach:26257/benchmark?sslmode=disable"; fi
  if [ "$LANG" = "zig" ]; then PG_HOST="cockroach"; fi

  case "$LANG" in

    v|nim|zig)
      if ! "${COMMON[@]}" \
        -e "PGHOST=$PG_HOST" \
        -e "PGPORT=$DB_PORT" \
        -e "PGUSER=$DB_USER" \
        -e "PGPASSWORD=" \
        -e "PGDATABASE=$DB_NAME" \
        -e "PGSSLMODE=disable" \
        "$IMAGE" >/dev/null; then
        FAILED+=("$LANG")
        continue
      fi
      ;;

    *)
      if ! "${COMMON[@]}" \
        -e "DATABASE_URL=$APP_DATABASE_URL" \
        "$IMAGE" >/dev/null; then
        FAILED+=("$LANG")
        continue
      fi
      ;;

  esac

  echo "Prepared: $CONTAINER"

done

echo
echo "=========================================================="

if [ "${#FAILED[@]}" -eq 0 ]; then
  echo "ALL 13 COCKROACHDB IMPLEMENTATIONS PREPARED"
else
  echo "FAILED: ${FAILED[*]}"
fi

echo "=========================================================="

[ "${#FAILED[@]}" -eq 0 ]
