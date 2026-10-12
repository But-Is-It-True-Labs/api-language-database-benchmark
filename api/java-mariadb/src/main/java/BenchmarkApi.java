import io.vertx.core.Vertx;
import io.vertx.core.json.JsonArray;
import io.vertx.core.json.JsonObject;

import io.vertx.ext.web.Router;
import io.vertx.ext.web.RoutingContext;
import io.vertx.ext.web.handler.BodyHandler;

import io.vertx.mysqlclient.MySQLConnectOptions;

import io.vertx.sqlclient.PoolOptions;
import io.vertx.sqlclient.Row;
import io.vertx.sqlclient.RowSet;
import io.vertx.sqlclient.Tuple;

import io.vertx.mysqlclient.MySQLPool;

import java.time.LocalDateTime;


public class BenchmarkApi {

    private static MySQLPool pool;


    private static JsonObject parentJson(Row row) {

        LocalDateTime createdAt =
            row.getLocalDateTime("created_at");

        return new JsonObject()
            .put("id", row.getLong("id"))
            .put(
                "account_number",
                row.getLong("account_number")
            )
            .put(
                "status",
                row.getString("status")
            )
            .put(
                "created_at",
                createdAt.toString()
            )
            .put(
                "payload",
                row.getString("payload")
            );
    }


    private static JsonObject childJson(Row row) {

        return new JsonObject()
            .put(
                "id",
                row.getLong("id")
            )
            .put(
                "parent_id",
                row.getLong("parent_id")
            )
            .put(
                "sequence_number",
                row.getInteger("sequence_number")
            )
            .put(
                "value_number",
                row.getInteger("value_number")
            )
            .put(
                "payload",
                row.getString("payload")
            );
    }


    private static JsonObject eventJson(Row row) {

        LocalDateTime eventTime =
            row.getLocalDateTime("event_time");

        return new JsonObject()
            .put(
                "id",
                row.getLong("id")
            )
            .put(
                "parent_id",
                row.getLong("parent_id")
            )
            .put(
                "event_type",
                row.getString("event_type")
            )
            .put(
                "event_time",
                eventTime.toString()
            )
            .put(
                "payload",
                row.getString("payload")
            );
    }


    private static void json(
        RoutingContext ctx,
        int status,
        Object value
    ) {

        ctx.response()
            .setStatusCode(status)
            .putHeader(
                "Content-Type",
                "application/json"
            )
            .end(
                value instanceof JsonObject
                    ? ((JsonObject) value).encode()
                    : ((JsonArray) value).encode()
            );
    }


    private static void text(
        RoutingContext ctx,
        int status,
        String value
    ) {

        ctx.response()
            .setStatusCode(status)
            .end(value);
    }


    private static long id(
        RoutingContext ctx
    ) {

        return Long.parseLong(
            ctx.pathParam("id")
        );
    }


    private static void health(
        RoutingContext ctx
    ) {

        pool.query("SELECT 1")
            .execute()

            .onSuccess(result ->
                json(
                    ctx,
                    200,
                    new JsonObject()
                        .put("status", "ok")
                )
            )

            .onFailure(error -> {
                System.err.println("DATABASE HEALTH CHECK FAILED:");
                error.printStackTrace();

                json(
                    ctx,
                    503,
                    new JsonObject()
                        .put(
                            "status",
                            "database unavailable"
                        )
                );
            });
    }



    private static final java.util.concurrent.atomic.AtomicInteger
        mariaDbErrors = new java.util.concurrent.atomic.AtomicInteger();

    private static void parent(
        RoutingContext ctx
    ) {

        long parentId;

        try {
            parentId = id(ctx);
        } catch (Exception e) {
            text(
                ctx,
                400,
                "invalid parent id"
            );
            return;
        }

        pool.preparedQuery(
            """
            SELECT
                id,
                account_number,
                status,
                created_at,
                payload
            FROM benchmark_parent
            WHERE id = ?
            """
        )
        .execute(
            Tuple.of(parentId)
        )

        .onSuccess(rows -> {

            Row row = rows.iterator()
                .hasNext()
                    ? rows.iterator().next()
                    : null;

            if (row == null) {
                text(
                    ctx,
                    404,
                    "parent not found"
                );
                return;
            }

            json(
                ctx,
                200,
                parentJson(row)
            );
        })

        .onFailure(error -> {
            if (mariaDbErrors.incrementAndGet() <= 10) {
                System.err.println("MARIADB QUERY FAILURE:");
                error.printStackTrace(System.err);
            }
            text(ctx, 500, "query failed");
        });
    }


    private static void children(
        RoutingContext ctx
    ) {

        long parentId;

        try {
            parentId = id(ctx);
        } catch (Exception e) {
            text(
                ctx,
                400,
                "invalid parent id"
            );
            return;
        }

        pool.preparedQuery(
            """
            SELECT
                id,
                parent_id,
                sequence_number,
                value_number,
                payload
            FROM benchmark_child
            WHERE parent_id = ?
            ORDER BY id
            """
        )
        .execute(
            Tuple.of(parentId)
        )

        .onSuccess(rows -> {

            JsonArray result =
                new JsonArray();

            for (Row row : rows) {
                result.add(
                    childJson(row)
                );
            }

            json(
                ctx,
                200,
                result
            );
        })

        .onFailure(error ->
            text(
                ctx,
                500,
                "query failed"
            )
        );
    }


    private static void events(
        RoutingContext ctx
    ) {

        long parentId;

        try {
            parentId = id(ctx);
        } catch (Exception e) {
            text(
                ctx,
                400,
                "invalid parent id"
            );
            return;
        }

        pool.preparedQuery(
            """
            SELECT
                id,
                parent_id,
                event_type,
                event_time,
                payload
            FROM benchmark_event
            WHERE parent_id = ?
            ORDER BY event_time DESC, id DESC
            LIMIT 20
            """
        )
        .execute(
            Tuple.of(parentId)
        )

        .onSuccess(rows -> {

            JsonArray result =
                new JsonArray();

            for (Row row : rows) {
                result.add(
                    eventJson(row)
                );
            }

            json(
                ctx,
                200,
                result
            );
        })

        .onFailure(error ->
            text(
                ctx,
                500,
                "query failed"
            )
        );
    }


    private static void accountParents(
        RoutingContext ctx
    ) {

        long accountId;

        try {
            accountId = id(ctx);
        } catch (Exception e) {
            text(
                ctx,
                400,
                "invalid account id"
            );
            return;
        }

        pool.preparedQuery(
            """
            SELECT
                id,
                account_number,
                status,
                created_at,
                payload
            FROM benchmark_parent
            WHERE account_number = ?
            ORDER BY id
            LIMIT 50
            """
        )
        .execute(
            Tuple.of(accountId)
        )

        .onSuccess(rows -> {

            JsonArray result =
                new JsonArray();

            for (Row row : rows) {
                result.add(
                    parentJson(row)
                );
            }

            json(
                ctx,
                200,
                result
            );
        })

        .onFailure(error ->
            text(
                ctx,
                500,
                "query failed"
            )
        );
    }


    private static void bundle(
        RoutingContext ctx
    ) {

        long parentId;

        try {
            parentId = id(ctx);
        } catch (Exception e) {
            text(
                ctx,
                400,
                "invalid parent id"
            );
            return;
        }

        pool.preparedQuery(
            """
            SELECT
                id,
                account_number,
                status,
                created_at,
                payload
            FROM benchmark_parent
            WHERE id = ?
            """
        )
        .execute(
            Tuple.of(parentId)
        )

        .onSuccess(parentRows -> {

            var iterator =
                parentRows.iterator();

            if (!iterator.hasNext()) {
                text(
                    ctx,
                    404,
                    "parent not found"
                );
                return;
            }

            JsonObject parent =
                parentJson(
                    iterator.next()
                );

            pool.preparedQuery(
                """
                SELECT
                    id,
                    parent_id,
                    sequence_number,
                    value_number,
                    payload
                FROM benchmark_child
                WHERE parent_id = ?
                ORDER BY id
                """
            )
            .execute(
                Tuple.of(parentId)
            )

            .onSuccess(childRows -> {

                JsonArray children =
                    new JsonArray();

                for (Row row : childRows) {
                    children.add(
                        childJson(row)
                    );
                }

                pool.preparedQuery(
                    """
                    SELECT
                        id,
                        parent_id,
                        event_type,
                        event_time,
                        payload
                    FROM benchmark_event
                    WHERE parent_id = ?
                    ORDER BY event_time DESC, id DESC
                    LIMIT 20
                    """
                )
                .execute(
                    Tuple.of(parentId)
                )

                .onSuccess(eventRows -> {

                    JsonArray events =
                        new JsonArray();

                    for (Row row : eventRows) {
                        events.add(
                            eventJson(row)
                        );
                    }

                    json(
                        ctx,
                        200,
                        new JsonObject()
                            .put(
                                "parent",
                                parent
                            )
                            .put(
                                "children",
                                children
                            )
                            .put(
                                "events",
                                events
                            )
                    );
                })

                .onFailure(error ->
                    text(
                        ctx,
                        500,
                        "event query failed"
                    )
                );
            })

            .onFailure(error ->
                text(
                    ctx,
                    500,
                    "child query failed"
                )
            );
        })

        .onFailure(error ->
            text(
                ctx,
                500,
                "parent query failed"
            )
        );
    }


    private static void createEvent(
        RoutingContext ctx
    ) {

        try {

            JsonObject body =
                ctx.getBodyAsJson();

            Number idValue =
                (Number) body.getValue("id");

            Number parentValue =
                (Number) body.getValue(
                    "parent_id"
                );

            String eventType =
                body.getString(
                    "event_type"
                );

            String payload =
                body.getString(
                    "payload"
                );

            if (
                idValue == null ||
                parentValue == null ||
                eventType == null ||
                payload == null
            ) {

                text(
                    ctx,
                    400,
                    "invalid json"
                );

                return;
            }

            long eventId =
                idValue.longValue();

            long parentId =
                parentValue.longValue();

            pool.preparedQuery(
                """
                INSERT INTO benchmark_event
                (
                    id,
                    parent_id,
                    event_type,
                    event_time,
                    payload
                )
                VALUES
                (
                    ?,
                    ?,
                    ?,
                    CURRENT_TIMESTAMP,
                    ?
                )
                """
            )
            .execute(
                Tuple.of(
                    eventId,
                    parentId,
                    eventType,
                    payload
                )
            )

            .onSuccess(result ->
                json(
                    ctx,
                    201,
                    new JsonObject()
                        .put(
                            "created",
                            true
                        )
                        .put(
                            "id",
                            eventId
                        )
                )
            )

            .onFailure(error ->
                text(
                    ctx,
                    500,
                    "insert failed"
                )
            );

        } catch (Exception e) {

            text(
                ctx,
                400,
                "invalid json"
            );
        }
    }


    public static void main(
        String[] args
    ) {

        String databaseUrl =
            System.getenv(
                "DATABASE_URL"
            );

        if (
            databaseUrl == null ||
            databaseUrl.isBlank()
        ) {
            throw new IllegalStateException(
                "DATABASE_URL is required"
            );
        }

        MySQLConnectOptions connect =
            MySQLConnectOptions.fromUri(
                databaseUrl
            );

        PoolOptions poolOptions =
            new PoolOptions()
                .setMaxSize(50);

        Vertx vertx =
            Vertx.vertx();

        pool =
            MySQLPool.pool(
                vertx,
                connect,
                poolOptions
            );

        Router router =
            Router.router(vertx);

        router.route()
            .handler(
                BodyHandler.create()
            );

        router.get("/health")
            .handler(
                BenchmarkApi::health
            );

        router.get("/parent/:id")
            .handler(
                BenchmarkApi::parent
            );

        router.get(
            "/parent/:id/children"
        )
        .handler(
            BenchmarkApi::children
        );

        router.get(
            "/parent/:id/events"
        )
        .handler(
            BenchmarkApi::events
        );

        router.get(
            "/parent/:id/bundle"
        )
        .handler(
            BenchmarkApi::bundle
        );

        router.get(
            "/account/:id/parents"
        )
        .handler(
            BenchmarkApi::accountParents
        );

        router.post("/event")
            .handler(
                BenchmarkApi::createEvent
            );

        vertx.createHttpServer()
            .requestHandler(router)

            .listen(8080, "0.0.0.0")

            .onSuccess(server ->
                System.out.println(
                    "Java/Vert.x benchmark API listening on :8080"
                )
            )

            .onFailure(error -> {
                error.printStackTrace();
                System.exit(1);
            });
    }
}
