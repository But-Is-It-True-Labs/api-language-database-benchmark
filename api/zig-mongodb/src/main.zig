const std=@import("std");const zap=@import("zap");
extern fn benchmark_mongo_health() c_int;
extern fn benchmark_mongo_parent(i64) ?[*:0]u8;
extern fn benchmark_mongo_free([*:0]u8) void;
fn onRequest(r:zap.Request) !void {
 const path=r.path orelse {r.setStatus(.not_found);try r.sendJson("not found");return;};
 if(std.mem.eql(u8,path,"/health")){if(benchmark_mongo_health()!=0){try r.sendJson("{\"status\":\"ok\"}");}else{r.setStatus(.service_unavailable);try r.sendJson("{\"status\":\"database unavailable\"}");}return;}
 if(std.mem.startsWith(u8,path,"/parent/")){
  const id=std.fmt.parseInt(i64,path[8..],10) catch {r.setStatus(.bad_request);try r.sendJson("{\"error\":\"invalid id\"}");return;};
  const s=benchmark_mongo_parent(id) orelse {r.setStatus(.not_found);try r.sendJson("{\"error\":\"parent not found\"}");return;};defer benchmark_mongo_free(s);
  try r.sendJson(std.mem.span(s));return;
 }
 r.setStatus(.not_found);try r.sendJson("{\"error\":\"not found\"}");
}
pub fn main(_:std.process.Init) !void {var listener=zap.HttpListener.init(.{.port=8080,.on_request=onRequest,.log=false,.max_clients=100000});try listener.listen();zap.start(.{.threads=50,.workers=1});}
