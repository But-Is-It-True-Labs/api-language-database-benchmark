import com.datastax.oss.driver.api.core.CqlIdentifier;
import com.datastax.oss.driver.api.core.CqlSession;
import com.datastax.oss.driver.api.core.DefaultConsistencyLevel;

import com.datastax.oss.driver.api.core.cql.AsyncResultSet;
import com.datastax.oss.driver.api.core.cql.PreparedStatement;
import com.datastax.oss.driver.api.core.cql.Row;

import io.vertx.core.Vertx;
import io.vertx.core.json.JsonObject;

import io.vertx.ext.web.Router;
import io.vertx.ext.web.RoutingContext;

import java.net.InetSocketAddress;
import java.time.Instant;


public class BenchmarkApi {

    private static CqlSession session;

    private static PreparedStatement parentStatement;
    private static PreparedStatement healthStatement;


    private static void json(
        RoutingContext ctx,
        int status,
        JsonObject value
    ) {

        ctx.response()
            .setStatusCode(status)
            .putHeader(
                "Content-Type",
                "application/json"
            )
            .end(value.encode());
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


    private static JsonObject parentJson(
        Row row
    ) {

        Instant createdAt =
            row.getInstant(
                "created_at"
            );

        return new JsonObject()
            .put(
                "id",
                row.getLong("id")
            )
            .put(
                "account_number",
                row.getLong(
                    "account_number"
                )
            )
            .put(
                "status",
                row.getString(
                    "status"
                )
            )
            .put(
                "created_at",
                createdAt != null
                    ? createdAt.toString()
                    : null
            )
            .put(
                "payload",
                row.getString(
                    "payload"
                )
            );
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

        session.executeAsync(
            healthStatement
                .bind("local")
                .setConsistencyLevel(
                    DefaultConsistencyLevel.ONE
                )
        )
        .whenComplete(
            (
                result,
                error
            ) -> {

                ctx.vertx()
                    .runOnContext(
                        ignored -> {

                            if (error != null) {

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

                                return;
                            }

                            json(
                                ctx,
                                200,
                                new JsonObject()
                                    .put(
                                        "status",
                                        "ok"
                                    )
                            );
                        }
                    );
            }
        );
    }


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


        session.executeAsync(
            parentStatement
                .bind(parentId)
                .setConsistencyLevel(
                    DefaultConsistencyLevel.ONE
                )
        )
        .whenComplete(
            (
                result,
                error
            ) -> {

                ctx.vertx()
                    .runOnContext(
                        ignored -> {

                            if (error != null) {

                                error.printStackTrace();

                                text(
                                    ctx,
                                    500,
                                    "query failed"
                                );

                                return;
                            }


                            Row row =
                                result.one();


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
                        }
                    );
            }
        );
    }


    public static void main(
        String[] args
    ) {

        String host =
            System.getenv(
                "CASSANDRA_HOST"
            );


        if (
            host == null ||
            host.isBlank()
        ) {

            host =
                "benchmark_cassandra";
        }


        session =
            CqlSession.builder()

                .addContactPoint(
                    new InetSocketAddress(
                        host,
                        9042
                    )
                )

                .withLocalDatacenter(
                    "datacenter1"
                )

                .withKeyspace(
                    CqlIdentifier.fromCql(
                        "benchmark"
                    )
                )

                .build();


        parentStatement =
            session.prepare(
                """
                SELECT
                    id,
                    account_number,
                    status,
                    created_at,
                    payload
                FROM parent_by_id
                WHERE id = ?
                """
            );


        healthStatement =
            session.prepare(
                """
                SELECT release_version
                FROM system.local
                WHERE key = ?
                """
            );


        Vertx vertx =
            Vertx.vertx();


        Router router =
            Router.router(
                vertx
            );


        router.get("/health")
            .handler(
                BenchmarkApi::health
            );


        router.get("/parent/:id")
            .handler(
                BenchmarkApi::parent
            );


        vertx.createHttpServer()

            .requestHandler(
                router
            )

            .listen(
                8080,
                "0.0.0.0"
            )

            .onSuccess(
                server ->
                    System.out.println(
                        "Java/Vert.x Cassandra benchmark API listening on :8080"
                    )
            )

            .onFailure(
                error -> {

                    error.printStackTrace();

                    System.exit(1);
                }
            );


        Runtime.getRuntime()
            .addShutdownHook(
                new Thread(
                    () -> {

                        if (session != null) {
                            session.close();
                        }
                    }
                )
            );
    }
}
