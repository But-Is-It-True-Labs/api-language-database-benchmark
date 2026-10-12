module main
import veb
#flag -I.
#flag -L/usr/local/lib -lbenchmark_mongo_bridge
#include "mongo_bridge.h"
fn C.benchmark_mongo_health() int
fn C.benchmark_mongo_parent(i64) &char
fn C.benchmark_mongo_free(&char)
pub struct Context {veb.Context}
pub struct App {}
@['/health']
pub fn (app &App) health(mut ctx Context) veb.Result {
  if C.benchmark_mongo_health()!=0 {return ctx.text('{"status":"ok"}')}
  return ctx.text('{"status":"database unavailable"}')
}
@['/parent/:id']
pub fn (app &App) parent(mut ctx Context,id string) veb.Result {
  n:=id.i64()
  p:=C.benchmark_mongo_parent(n)
  if isnil(p) {return ctx.text('{"error":"parent not found"}')}
  result:=unsafe {p.vstring().clone()}
  C.benchmark_mongo_free(p)
  return ctx.text(result)
}
fn main(){mut app:=&App{};veb.run_at[App,Context](mut app,family:.ip,port:8080) or {panic(err)}}
