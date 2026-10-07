import mummy
import mummy/routers

import std/json
import std/os
import std/strutils


const
  WorkerThreads = 50
  BridgeLib = "libbenchmark_cassandra_bridge.so"


proc bc_init(host: cstring): cint
  {.cdecl, importc, dynlib: BridgeLib.}

proc bc_health(): cint
  {.cdecl, importc, dynlib: BridgeLib, gcsafe.}

proc bc_get_parent(id: int64): cint
  {.cdecl, importc, dynlib: BridgeLib, gcsafe.}

proc bc_parent_id(): int64
  {.cdecl, importc, dynlib: BridgeLib, gcsafe.}

proc bc_parent_account_number(): int64
  {.cdecl, importc, dynlib: BridgeLib, gcsafe.}

proc bc_parent_status(): cstring
  {.cdecl, importc, dynlib: BridgeLib, gcsafe.}

proc bc_parent_created_at(): cstring
  {.cdecl, importc, dynlib: BridgeLib, gcsafe.}

proc bc_parent_payload(): cstring
  {.cdecl, importc, dynlib: BridgeLib, gcsafe.}


proc jsonHeaders(): HttpHeaders =
  result["Content-Type"] =
    "application/json"


proc healthHandler(
  request: Request
) {.gcsafe.} =
  if bc_health() == 0:
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


proc parentHandler(
  request: Request
) {.gcsafe.} =
  const prefix =
    "/parent/"

  if not request.path.startsWith(
    prefix
  ):
    request.respond(
      404,
      jsonHeaders(),
      """{"error":"not found"}"""
    )

    return

  let idText =
    request.path[
      prefix.len .. ^1
    ]

  if idText.len == 0:
    request.respond(
      404,
      jsonHeaders(),
      """{"error":"parent not found"}"""
    )

    return

  var id: int64

  try:
    id =
      parseBiggestInt(
        idText
      ).int64

  except ValueError:
    request.respond(
      400,
      jsonHeaders(),
      """{"error":"invalid parent id"}"""
    )

    return

  let rc =
    bc_get_parent(
      id
    )

  if rc == 1:
    request.respond(
      404,
      jsonHeaders(),
      """{"error":"parent not found"}"""
    )

    return

  if rc != 0:
    request.respond(
      500,
      jsonHeaders(),
      """{"error":"query failed"}"""
    )

    return

  let body = %*{
    "id":
      bc_parent_id(),

    "account_number":
      bc_parent_account_number(),

    "status":
      $bc_parent_status(),

    "created_at":
      $bc_parent_created_at(),

    "payload":
      $bc_parent_payload()
  }

  request.respond(
    200,
    jsonHeaders(),
    $body
  )


let cassandraHost =
  getEnv(
    "CASSANDRA_HOST",
    "benchmark_cassandra"
  )

if bc_init(
    cassandraHost.cstring
  ) != 0:
  quit(
    "Unable to initialize Cassandra"
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


let server =
  newServer(
    router,
    workerThreads =
      WorkerThreads
  )


echo "Nim/Mummy Cassandra benchmark API listening on :8080"
echo "Worker threads: ", WorkerThreads


server.serve(
  Port(8080),
  "0.0.0.0"
)
