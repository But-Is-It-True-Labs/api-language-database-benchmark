#include <microhttpd.h>
#include <libpq-fe.h>
#include <nlohmann/json.hpp>

#include <condition_variable>
#include <cstdlib>
#include <cstring>
#include <iostream>
#include <memory>
#include <mutex>
#include <queue>
#include <string>
#include <thread>
#include <chrono>
#include <vector>

using json = nlohmann::json;

class PgPool {
public:
    PgPool(const std::string& connection_string, std::size_t size) {
        for (std::size_t i = 0; i < size; ++i) {
            PGconn* connection = PQconnectdb(connection_string.c_str());

            if (PQstatus(connection) != CONNECTION_OK) {
                std::string error = PQerrorMessage(connection);
                PQfinish(connection);
                throw std::runtime_error(error);
            }

            connections_.push(connection);
        }
    }

    ~PgPool() {
        while (!connections_.empty()) {
            PQfinish(connections_.front());
            connections_.pop();
        }
    }

    PGconn* acquire() {
        std::unique_lock lock(mutex_);

        cv_.wait(lock, [&] {
            return !connections_.empty();
        });

        PGconn* connection = connections_.front();
        connections_.pop();

        return connection;
    }

    void release(PGconn* connection) {
        {
            std::lock_guard lock(mutex_);
            connections_.push(connection);
        }

        cv_.notify_one();
    }

private:
    std::queue<PGconn*> connections_;
    std::mutex mutex_;
    std::condition_variable cv_;
};


static std::unique_ptr<PgPool> db;


static int send_json(
    MHD_Connection* connection,
    unsigned int status,
    const json& value
) {
    std::string body = value.dump();

    MHD_Response* response =
        MHD_create_response_from_buffer(
            body.size(),
            const_cast<char*>(body.data()),
            MHD_RESPMEM_MUST_COPY
        );

    MHD_add_response_header(
        response,
        "Content-Type",
        "application/json"
    );

    int result =
        MHD_queue_response(
            connection,
            status,
            response
        );

    MHD_destroy_response(response);

    return result;
}


static int send_text(
    MHD_Connection* connection,
    unsigned int status,
    const std::string& body
) {
    MHD_Response* response =
        MHD_create_response_from_buffer(
            body.size(),
            const_cast<char*>(body.data()),
            MHD_RESPMEM_MUST_COPY
        );

    int result =
        MHD_queue_response(
            connection,
            status,
            response
        );

    MHD_destroy_response(response);

    return result;
}


static json parent_json(PGresult* result, int row) {
    return {
        {"id", std::stoll(PQgetvalue(result, row, 0))},
        {"account_number", std::stoll(PQgetvalue(result, row, 1))},
        {"status", PQgetvalue(result, row, 2)},
        {"created_at", PQgetvalue(result, row, 3)},
        {"payload", PQgetvalue(result, row, 4)}
    };
}


static json child_json(PGresult* result, int row) {
    return {
        {"id", std::stoll(PQgetvalue(result, row, 0))},
        {"parent_id", std::stoll(PQgetvalue(result, row, 1))},
        {"sequence_number", std::stoi(PQgetvalue(result, row, 2))},
        {"value_number", std::stoi(PQgetvalue(result, row, 3))},
        {"payload", PQgetvalue(result, row, 4)}
    };
}


static json event_json(PGresult* result, int row) {
    return {
        {"id", std::stoll(PQgetvalue(result, row, 0))},
        {"parent_id", std::stoll(PQgetvalue(result, row, 1))},
        {"event_type", PQgetvalue(result, row, 2)},
        {"event_time", PQgetvalue(result, row, 3)},
        {"payload", PQgetvalue(result, row, 4)}
    };
}


static PGresult* query_one_param(
    PGconn* connection,
    const char* sql,
    const std::string& parameter
) {
    const char* values[1] = {
        parameter.c_str()
    };

    return PQexecParams(
        connection,
        sql,
        1,
        nullptr,
        values,
        nullptr,
        nullptr,
        0
    );
}


static int handle_get(
    MHD_Connection* connection,
    const std::string& path
) {
    PGconn* pg = db->acquire();

    try {

        if (path == "/health") {
            PGresult* result =
                PQexec(pg, "SELECT 1");

            bool ok =
                PQresultStatus(result) ==
                PGRES_TUPLES_OK;

            PQclear(result);
            db->release(pg);

            if (!ok) {
                return send_json(
                    connection,
                    503,
                    {{"status", "database unavailable"}}
                );
            }

            return send_json(
                connection,
                200,
                {{"status", "ok"}}
            );
        }


        const std::string parent_prefix = "/parent/";

        if (
            path.starts_with(parent_prefix) &&
            path.find('/', parent_prefix.size()) ==
                std::string::npos
        ) {
            std::string id =
                path.substr(
                    parent_prefix.size()
                );

            PGresult* result =
                query_one_param(
                    pg,
                    R"SQL(
                        SELECT
                            id,
                            account_number,
                            status,
                            created_at,
                            payload
                        FROM benchmark_parent
                        WHERE id = $1
                    )SQL",
                    id
                );

            if (
                PQresultStatus(result) !=
                PGRES_TUPLES_OK
            ) {
                PQclear(result);
                db->release(pg);

                return send_text(
                    connection,
                    500,
                    "query failed"
                );
            }

            if (PQntuples(result) == 0) {
                PQclear(result);
                db->release(pg);

                return send_text(
                    connection,
                    404,
                    "parent not found"
                );
            }

            json body =
                parent_json(
                    result,
                    0
                );

            PQclear(result);
            db->release(pg);

            return send_json(
                connection,
                200,
                body
            );
        }


        auto suffix_handler =
            [&](const std::string& suffix)
            -> std::string {

                if (
                    !path.starts_with(parent_prefix) ||
                    !path.ends_with(suffix)
                ) {
                    return "";
                }

                auto end =
                    path.size() -
                    suffix.size();

                return path.substr(
                    parent_prefix.size(),
                    end - parent_prefix.size()
                );
            };


        std::string children_id =
            suffix_handler("/children");

        if (!children_id.empty()) {
            PGresult* result =
                query_one_param(
                    pg,
                    R"SQL(
                        SELECT
                            id,
                            parent_id,
                            sequence_number,
                            value_number,
                            payload
                        FROM benchmark_child
                        WHERE parent_id = $1
                        ORDER BY id
                    )SQL",
                    children_id
                );

            json body =
                json::array();

            for (
                int i = 0;
                i < PQntuples(result);
                ++i
            ) {
                body.push_back(
                    child_json(
                        result,
                        i
                    )
                );
            }

            PQclear(result);
            db->release(pg);

            return send_json(
                connection,
                200,
                body
            );
        }


        std::string events_id =
            suffix_handler("/events");

        if (!events_id.empty()) {
            PGresult* result =
                query_one_param(
                    pg,
                    R"SQL(
                        SELECT
                            id,
                            parent_id,
                            event_type,
                            event_time,
                            payload
                        FROM benchmark_event
                        WHERE parent_id = $1
                        ORDER BY event_time DESC, id DESC
                        LIMIT 20
                    )SQL",
                    events_id
                );

            json body =
                json::array();

            for (
                int i = 0;
                i < PQntuples(result);
                ++i
            ) {
                body.push_back(
                    event_json(
                        result,
                        i
                    )
                );
            }

            PQclear(result);
            db->release(pg);

            return send_json(
                connection,
                200,
                body
            );
        }


        std::string bundle_id =
            suffix_handler("/bundle");

        if (!bundle_id.empty()) {
            PGresult* parent =
                query_one_param(
                    pg,
                    R"SQL(
                        SELECT
                            id,
                            account_number,
                            status,
                            created_at,
                            payload
                        FROM benchmark_parent
                        WHERE id = $1
                    )SQL",
                    bundle_id
                );

            if (PQntuples(parent) == 0) {
                PQclear(parent);
                db->release(pg);

                return send_text(
                    connection,
                    404,
                    "parent not found"
                );
            }

            PGresult* children =
                query_one_param(
                    pg,
                    R"SQL(
                        SELECT
                            id,
                            parent_id,
                            sequence_number,
                            value_number,
                            payload
                        FROM benchmark_child
                        WHERE parent_id = $1
                        ORDER BY id
                    )SQL",
                    bundle_id
                );

            PGresult* events =
                query_one_param(
                    pg,
                    R"SQL(
                        SELECT
                            id,
                            parent_id,
                            event_type,
                            event_time,
                            payload
                        FROM benchmark_event
                        WHERE parent_id = $1
                        ORDER BY event_time DESC, id DESC
                        LIMIT 20
                    )SQL",
                    bundle_id
                );

            json child_rows =
                json::array();

            for (
                int i = 0;
                i < PQntuples(children);
                ++i
            ) {
                child_rows.push_back(
                    child_json(
                        children,
                        i
                    )
                );
            }

            json event_rows =
                json::array();

            for (
                int i = 0;
                i < PQntuples(events);
                ++i
            ) {
                event_rows.push_back(
                    event_json(
                        events,
                        i
                    )
                );
            }

            json body = {
                {
                    "parent",
                    parent_json(
                        parent,
                        0
                    )
                },
                {
                    "children",
                    child_rows
                },
                {
                    "events",
                    event_rows
                }
            };

            PQclear(parent);
            PQclear(children);
            PQclear(events);

            db->release(pg);

            return send_json(
                connection,
                200,
                body
            );
        }


        const std::string account_prefix =
            "/account/";

        const std::string account_suffix =
            "/parents";

        if (
            path.starts_with(account_prefix) &&
            path.ends_with(account_suffix)
        ) {
            auto end =
                path.size() -
                account_suffix.size();

            std::string id =
                path.substr(
                    account_prefix.size(),
                    end -
                    account_prefix.size()
                );

            PGresult* result =
                query_one_param(
                    pg,
                    R"SQL(
                        SELECT
                            id,
                            account_number,
                            status,
                            created_at,
                            payload
                        FROM benchmark_parent
                        WHERE account_number = $1
                        ORDER BY id
                        LIMIT 50
                    )SQL",
                    id
                );

            json body =
                json::array();

            for (
                int i = 0;
                i < PQntuples(result);
                ++i
            ) {
                body.push_back(
                    parent_json(
                        result,
                        i
                    )
                );
            }

            PQclear(result);
            db->release(pg);

            return send_json(
                connection,
                200,
                body
            );
        }


        db->release(pg);

        return send_text(
            connection,
            404,
            "not found"
        );

    } catch (...) {
        db->release(pg);

        return send_text(
            connection,
            500,
            "internal server error"
        );
    }
}


static MHD_Result request_handler(
    void*,
    MHD_Connection* connection,
    const char* url,
    const char* method,
    const char*,
    const char*,
    size_t*,
    void**
) {
    if (
        std::strcmp(
            method,
            "GET"
        ) == 0
    ) {
        return static_cast<MHD_Result>(
            handle_get(
                connection,
                url
            )
        );
    }

    return static_cast<MHD_Result>(
        send_text(
            connection,
            405,
            "method not allowed"
        )
    );
}


int main() {
    const char* database_url =
        std::getenv(
            "DATABASE_URL"
        );

    if (!database_url) {
        std::cerr
            << "DATABASE_URL is required\n";

        return 1;
    }

    try {
        db =
            std::make_unique<PgPool>(
                database_url,
                50
            );

    } catch (
        const std::exception& error
    ) {
        std::cerr
            << "Database connection failed: "
            << error.what()
            << '\n';

        return 1;
    }

    MHD_Daemon* daemon =
        MHD_start_daemon(
            MHD_USE_INTERNAL_POLLING_THREAD |
            MHD_USE_THREAD_PER_CONNECTION,
            8080,
            nullptr,
            nullptr,
            &request_handler,
            nullptr,
            MHD_OPTION_END
        );

    if (!daemon) {
        std::cerr
            << "Failed to start HTTP server\n";

        return 1;
    }

    std::cout
        << "C++ benchmark API listening on :8080\n";

    while (true) {
        std::this_thread::sleep_for(
            std::chrono::hours(24)
        );
    }

    MHD_stop_daemon(daemon);

    return 0;
}
