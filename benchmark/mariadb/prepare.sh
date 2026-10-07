#!/usr/bin/env bash
set -u
set -o pipefail

NETWORK="api_benchmark_network"
DB_CONTAINER="benchmark_mariadb"

LANGS=(
  go rust node python php cpp java elixir ruby haskell v nim zig
)

if ! docker inspect "$DB_CONTAINER" >/dev/null 2>&1; then
  echo "ERROR: $DB_CONTAINER does not exist."
  exit 1
fi

get_db_env() {
  local key="$1"
  docker inspect "$DB_CONTAINER" \
    --format '{{range .Config.Env}}{{println .}}{{end}}' \
    | sed -n "s/^${key}=//p" \
    | head -n 1
}

DB_USER="$(get_db_env MARIADB_USER)"
DB_PASSWORD="$(get_db_env MARIADB_PASSWORD)"
DB_NAME="$(get_db_env MARIADB_DATABASE)"

if [ -z "$DB_USER" ] || [ -z "$DB_PASSWORD" ] || [ -z "$DB_NAME" ]; then
  echo "ERROR: Could not read MariaDB benchmark credentials from $DB_CONTAINER."
  exit 1
fi

URI="mysql://${DB_USER}:${DB_PASSWORD}@benchmark_mariadb:3306/${DB_NAME}"
GO_DSN="${DB_USER}:${DB_PASSWORD}@tcp(benchmark_mariadb:3306)/${DB_NAME}?parseTime=true"

FAILED=()

for LANG in "${LANGS[@]}"; do
  echo
  echo "=========================================================="
  echo "BUILDING ${LANG^^} + MARIADB"
  echo "=========================================================="

  IMAGE="benchmark-${LANG}-mariadb"
  CONTAINER="benchmark_${LANG}_mariadb"
  DIR="./api/${LANG}-mariadb"

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

  case "$LANG" in
    go)
      "${COMMON[@]}" \
        -e "DATABASE_URL=$GO_DSN" \
        "$IMAGE" >/dev/null
      ;;
    rust|node|python|php|java|elixir|ruby)
      "${COMMON[@]}" \
        -e "DATABASE_URL=$URI" \
        "$IMAGE" >/dev/null
      ;;
    cpp|haskell|v|nim|zig)
      "${COMMON[@]}" \
        -e "MYSQLHOST=benchmark_mariadb" \
        -e "MYSQLPORT=3306" \
        -e "MYSQLUSER=$DB_USER" \
        -e "MYSQLPASSWORD=$DB_PASSWORD" \
        -e "MYSQLDATABASE=$DB_NAME" \
        "$IMAGE" >/dev/null
      ;;
  esac

  echo "Prepared: $CONTAINER"
done

echo
echo "=========================================================="
if [ "${#FAILED[@]}" -eq 0 ]; then
  echo "ALL MARIADB API IMAGES BUILT AND CONTAINERS PREPARED"
else
  echo "BUILD FAILURES: ${FAILED[*]}"
fi
echo "=========================================================="

[ "${#FAILED[@]}" -eq 0 ]
