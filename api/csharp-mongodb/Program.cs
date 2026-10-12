using MongoDB.Driver;
using MongoDB.Bson;
var builder=WebApplication.CreateBuilder(args);
var app=builder.Build();
var client=new MongoClient(Environment.GetEnvironmentVariable("MONGO_URL") ?? throw new Exception("MONGO_URL missing"));
var coll=client.GetDatabase("benchmark").GetCollection<BsonDocument>("benchmark_parent");
app.MapGet("/health",async()=>{try{await client.GetDatabase("admin").RunCommandAsync<BsonDocument>(new BsonDocument("ping",1));return Results.Ok(new{status="ok"});}catch{return Results.Json(new{status="database unavailable"},statusCode:503);}});
app.MapGet("/parent/{id:long}",async(long id)=>{
 var p=await coll.Find(new BsonDocument("_id",id)).FirstOrDefaultAsync();
 if(p is null)return Results.NotFound();
 return Results.Ok(new{id=p["id"].ToInt64(),account_number=p["account_number"].ToInt64(),status=p["status"].AsString,created_at=p["created_at"].ToUniversalTime(),payload=p["payload"].AsString});
});
app.Run();
