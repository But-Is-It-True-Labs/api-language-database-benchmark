using System.Text.Json;
using MySqlConnector;

var builder = WebApplication.CreateBuilder(args);

builder.Services.ConfigureHttpJsonOptions(options =>
{
    options.SerializerOptions.PropertyNamingPolicy =
        JsonNamingPolicy.SnakeCaseLower;
});

var app = builder.Build();

var connectionBuilder = new MySqlConnectionStringBuilder
{
    Server = Environment.GetEnvironmentVariable("DB_HOST")
        ?? "benchmark_mariadb",
    Port = 3306,
    Database = "benchmark",
    UserID = "benchmark",
    Password = Environment.GetEnvironmentVariable("DB_PASSWORD")
        ?? throw new Exception("DB_PASSWORD is required"),
    Pooling = true,
    MinimumPoolSize = 5,
    MaximumPoolSize = 50,
    ConnectionTimeout = 5
};

string connectionString = connectionBuilder.ConnectionString;

app.MapGet("/health", async (CancellationToken ct) =>
{
    await using var db = new MySqlConnection(connectionString);
    await db.OpenAsync(ct);
    return Results.Ok(new { status = "ok" });
});

app.MapGet("/parent/{id:long}", async (long id, CancellationToken ct) =>
{
    var rows = await Query(
        connectionString,
        """
        SELECT id, account_number, status, created_at, payload
        FROM benchmark_parent
        WHERE id = @id
        """,
        id,
        ReadParent,
        ct);

    return rows.Count == 0
        ? Results.NotFound()
        : Results.Ok(rows[0]);
});

app.MapGet("/parent/{id:long}/children",
    async (long id, CancellationToken ct) =>
{
    var rows = await Query(
        connectionString,
        """
        SELECT id, parent_id, sequence_number, value_number, payload
        FROM benchmark_child
        WHERE parent_id = @id
        ORDER BY id
        """,
        id,
        ReadChild,
        ct);

    return Results.Ok(rows);
});

app.MapGet("/parent/{id:long}/events",
    async (long id, CancellationToken ct) =>
{
    var rows = await Query(
        connectionString,
        """
        SELECT id, parent_id, event_type, event_time, payload
        FROM benchmark_event
        WHERE parent_id = @id
        ORDER BY event_time DESC, id DESC
        LIMIT 20
        """,
        id,
        ReadEvent,
        ct);

    return Results.Ok(rows);
});

app.MapGet("/parent/{id:long}/bundle",
    async (long id, CancellationToken ct) =>
{
    var parents = await Query(
        connectionString,
        """
        SELECT id, account_number, status, created_at, payload
        FROM benchmark_parent
        WHERE id = @id
        """,
        id,
        ReadParent,
        ct);

    if (parents.Count == 0)
        return Results.NotFound();

    var children = await Query(
        connectionString,
        """
        SELECT id, parent_id, sequence_number, value_number, payload
        FROM benchmark_child
        WHERE parent_id = @id ORDER BY id
        """,
        id,
        ReadChild,
        ct);

    var events = await Query(
        connectionString,
        """
        SELECT id, parent_id, event_type, event_time, payload
        FROM benchmark_event
        WHERE parent_id = @id
        ORDER BY event_time DESC, id DESC LIMIT 20
        """,
        id,
        ReadEvent,
        ct);

    return Results.Ok(new
    {
        parent = parents[0],
        children,
        events
    });
});

app.MapGet("/account/{id:long}/parents",
    async (long id, CancellationToken ct) =>
{
    var rows = await Query(
        connectionString,
        """
        SELECT id, account_number, status, created_at, payload
        FROM benchmark_parent
        WHERE account_number = @id
        ORDER BY id LIMIT 50
        """,
        id,
        ReadParent,
        ct);

    return Results.Ok(rows);
});

app.MapPost("/event", async (
    EventRequest request,
    CancellationToken ct) =>
{
    await using var db = new MySqlConnection(connectionString);
    await db.OpenAsync(ct);

    await using var cmd = db.CreateCommand();
    cmd.CommandText =
        """
        INSERT INTO benchmark_event
          (id, parent_id, event_type, event_time, payload)
        VALUES (@id, @parent, @type, CURRENT_TIMESTAMP, @payload)
        """;

    cmd.Parameters.AddWithValue("@id", request.Id);
    cmd.Parameters.AddWithValue("@parent", request.ParentId);
    cmd.Parameters.AddWithValue("@type", request.EventType);
    cmd.Parameters.AddWithValue("@payload", request.Payload);

    await cmd.ExecuteNonQueryAsync(ct);

    return Results.Json(
        new { created = true, id = request.Id },
        statusCode: 201);
});

app.Run();

static async Task<List<T>> Query<T>(
    string connectionString,
    string sql,
    long id,
    Func<MySqlDataReader, T> map,
    CancellationToken ct)
{
    await using var db = new MySqlConnection(connectionString);
    await db.OpenAsync(ct);

    await using var cmd = db.CreateCommand();
    cmd.CommandText = sql;
    cmd.Parameters.AddWithValue("@id", id);

    await using var reader = await cmd.ExecuteReaderAsync(ct);

    var results = new List<T>();

    while (await reader.ReadAsync(ct))
        results.Add(map(reader));

    return results;
}

static Parent ReadParent(MySqlDataReader r) =>
    new(
        r.GetInt64(0),
        r.GetInt64(1),
        r.GetString(2),
        DateTime.SpecifyKind(r.GetDateTime(3), DateTimeKind.Utc),
        r.GetString(4));

static Child ReadChild(MySqlDataReader r) =>
    new(
        r.GetInt64(0),
        r.GetInt64(1),
        r.GetInt32(2),
        r.GetInt32(3),
        r.GetString(4));

static BenchmarkEvent ReadEvent(MySqlDataReader r) =>
    new(
        r.GetInt64(0),
        r.GetInt64(1),
        r.GetString(2),
        DateTime.SpecifyKind(r.GetDateTime(3), DateTimeKind.Utc),
        r.GetString(4));

record Parent(
    long Id, long AccountNumber, string Status,
    DateTime CreatedAt, string Payload);

record Child(
    long Id, long ParentId, int SequenceNumber,
    int ValueNumber, string Payload);

record BenchmarkEvent(
    long Id, long ParentId, string EventType,
    DateTime EventTime, string Payload);

record EventRequest(
    long Id, long ParentId, string EventType, string Payload);
