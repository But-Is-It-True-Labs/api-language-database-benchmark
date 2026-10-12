using Npgsql;
var builder = WebApplication.CreateBuilder(args);
var app = builder.Build();
var cs = new NpgsqlConnectionStringBuilder {
 Host = Environment.GetEnvironmentVariable("PGHOST") ?? "benchmark_yugabyte",
 Port = int.Parse(Environment.GetEnvironmentVariable("PGPORT") ?? "5433"),
 Database = Environment.GetEnvironmentVariable("PGDATABASE") ?? "benchmark",
 Username = Environment.GetEnvironmentVariable("PGUSER") ?? "yugabyte",
 Password = Environment.GetEnvironmentVariable("PGPASSWORD") ?? "",
 SslMode = SslMode.Disable,
 Pooling = true,
 MaxPoolSize = 50
}.ConnectionString;
var data = NpgsqlDataSource.Create(cs);
app.MapGet("/health", async () => {
    try { await using var c=await data.OpenConnectionAsync(); await using var q=new NpgsqlCommand("SELECT 1",c); await q.ExecuteScalarAsync(); return Results.Ok(new {status="ok"}); }
    catch { return Results.Json(new {status="database unavailable"},statusCode:503); }
});
app.MapGet("/parent/{id:long}", async (long id) => {
    await using var c=await data.OpenConnectionAsync();
    await using var q=new NpgsqlCommand("SELECT id,account_number,status,created_at,payload FROM benchmark_parent WHERE id=@id",c);
    q.Parameters.AddWithValue("id",id);
    await using var r=await q.ExecuteReaderAsync();
    if (!await r.ReadAsync()) return Results.NotFound();
    return Results.Ok(new {id=r.GetInt64(0),account_number=r.GetInt64(1),status=r.GetString(2),created_at=DateTime.SpecifyKind(r.GetDateTime(3),DateTimeKind.Utc),payload=r.GetString(4)});
});
app.Run();
