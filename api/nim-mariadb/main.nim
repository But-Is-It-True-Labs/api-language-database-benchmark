import mummy
import mummy/routers

import db_connector/db_mysql

import std/json
import std/os
import std/strutils


const
  WorkerThreads = 50


var threadDb {.threadvar.}: DbConn


proc getDb(): DbConn {.gcsafe.} =
  if threadDb == nil:
    threadDb = db_mysql.open(
      getEnv("MYSQLHOST", "benchmark_mariadb"),
      getEnv("MYSQLUSER", "benchmark"),
      getEnv("MYSQLPASSWORD", "benchmark_password"),
      getEnv("MYSQLDATABASE", "benchmark")
    )

  return threadDb


proc jsonHeaders(): HttpHeaders =
  result["Content-Type"] = "application/json"


proc healthHandler(request: Request) {.gcsafe.} =
  try:
    let db = getDb()

    let row = db.getRow(
      sql"SELECT 1"
    )

    if row.len > 0 and row[0] == "1":
      request.respond(
        200,
        jsonHeaders(),
        """{"status":"ok"}"""
      )
    else:
      request.respond(
        503,
        jsonHeaders(),
        """{"status":"database unavailable"}"""
      )

  except CatchableError as e:
    stderr.writeLine(
      "health error: " & e.msg
    )

    request.respond(
      503,
      jsonHeaders(),
      """{"status":"database unavailable"}"""
    )


proc parentHandler(request: Request) {.gcsafe.} =
  try:
    const prefix = "/parent/"

    if not request.path.startsWith(prefix):
      request.respond(
        404,
        jsonHeaders(),
        """{"error":"not found"}"""
      )
      return

    let id = request.path[prefix.len .. ^1]

    if id.len == 0:
      request.respond(
        404,
        jsonHeaders(),
        """{"error":"parent not found"}"""
      )
      return

    let db = getDb()

    let row = db.getRow(
      sql"""
        SELECT
          id,
          account_number,
          status,
          created_at,
          payload
        FROM benchmark_parent
        WHERE id = ?
      """,
      id
    )

    if row.len < 5 or row[0].len == 0:
      request.respond(
        404,
        jsonHeaders(),
        """{"error":"parent not found"}"""
      )
      return

    let body = %*{
      "id": parseBiggestInt(row[0]),
      "account_number": parseBiggestInt(row[1]),
      "status": row[2],
      "created_at": row[3],
      "payload": row[4]
    }

    request.respond(
      200,
      jsonHeaders(),
      $body
    )

  except CatchableError as e:
    stderr.writeLine(
      "parent error: " & e.msg
    )

    request.respond(
      500,
      jsonHeaders(),
      """{"error":"query failed"}"""
    )


var router: Router

router.get(
  "/health",
  healthHandler
)

router.get(
  "/parent/*",
  parentHandler
)

let server = newServer(
  router,
  workerThreads = WorkerThreads
)

echo "Nim/Mummy benchmark API listening on :8080"
echo "Worker threads: ", WorkerThreads

server.serve(
  Port(8080),
  "0.0.0.0"
)
