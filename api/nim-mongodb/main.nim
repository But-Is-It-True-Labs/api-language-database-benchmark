import mummy
import mummy/routers
import std/strutils
proc mongoHealth(): cint {.importc:"benchmark_mongo_health",dynlib:"libbenchmark_mongo_bridge.so",gcsafe.}
proc mongoParent(id: int64): cstring {.importc:"benchmark_mongo_parent",dynlib:"libbenchmark_mongo_bridge.so",gcsafe.}
proc mongoFree(p: cstring) {.importc:"benchmark_mongo_free",dynlib:"libbenchmark_mongo_bridge.so",gcsafe.}
proc headers():HttpHeaders =
  result["Content-Type"]="application/json"
proc health(r:Request) {.gcsafe.} =
  if mongoHealth() != 0: r.respond(200,headers(),"""{"status":"ok"}""")
  else: r.respond(503,headers(),"""{"status":"database unavailable"}""")
proc parent(r:Request) {.gcsafe.} =
  try:
    let id = parseBiggestInt(r.path[8..^1])
    let p = mongoParent(id.int64)
    if p == nil: r.respond(404,headers(),"""{"error":"parent not found"}""")
    else:
      let data = $p
      mongoFree(p)
      r.respond(200,headers(),data)
  except CatchableError:
    r.respond(400,headers(),"""{"error":"invalid id"}""")
var router:Router
router.get("/health",health)
router.get("/parent/*",parent)
let server = newServer(router,workerThreads=50)
server.serve(Port(8080),"0.0.0.0")
