#include <cassandra.h>
#include <microhttpd.h>
#include <nlohmann/json.hpp>

#include <atomic>
#include <chrono>
#include <csignal>
#include <cstdlib>
#include <cstring>
#include <ctime>
#include <iostream>
#include <sstream>
#include <string>
#include <thread>

using json = nlohmann::json;

static CassCluster* cluster = nullptr;
static CassSession* session = nullptr;

static const CassPrepared* parent_prepared = nullptr;
static const CassPrepared* health_prepared = nullptr;

static std::atomic<bool> running{true};


static std::string cass_error(CassFuture* future)
{
    const char* message = nullptr;
    size_t message_length = 0;

    cass_future_error_message(
        future,
        &message,
        &message_length
    );

    return std::string(
        message ? message : "",
        message_length
    );
}


static bool future_ok(
    CassFuture* future,
    const char* label
)
{
    cass_future_wait(future);

    CassError rc =
        cass_future_error_code(future);

    if (rc != CASS_OK)
    {
        std::cerr
            << label
            << ": "
            << cass_error(future)
            << std::endl;

        return false;
    }

    return true;
}


static std::string get_string(
    const CassRow* row,
    const char* column
)
{
    const CassValue* value =
        cass_row_get_column_by_name(
            row,
            column
        );

    if (
        value == nullptr ||
        cass_value_is_null(value)
    )
    {
        return "";
    }

    const char* data = nullptr;
    size_t length = 0;

    if (
        cass_value_get_string(
            value,
            &data,
            &length
        ) != CASS_OK
    )
    {
        return "";
    }

    return std::string(
        data,
        length
    );
}


static cass_int64_t get_int64(
    const CassRow* row,
    const char* column
)
{
    const CassValue* value =
        cass_row_get_column_by_name(
            row,
            column
        );

    cass_int64_t result = 0;

    if (
        value != nullptr &&
        !cass_value_is_null(value)
    )
    {
        cass_value_get_int64(
            value,
            &result
        );
    }

    return result;
}


static std::string timestamp_to_iso(
    cass_int64_t milliseconds
)
{
    std::time_t seconds =
        static_cast<std::time_t>(
            milliseconds / 1000
        );

    int millis =
        static_cast<int>(
            milliseconds % 1000
        );

    if (millis < 0)
    {
        millis += 1000;
        --seconds;
    }

    std::tm tm{};

    gmtime_r(
        &seconds,
        &tm
    );

    char buffer[64];

    if (millis == 0)
    {
        std::strftime(
            buffer,
            sizeof(buffer),
            "%Y-%m-%dT%H:%M:%SZ",
            &tm
        );

        return buffer;
    }

    char date_buffer[48];

    std::strftime(
        date_buffer,
        sizeof(date_buffer),
        "%Y-%m-%dT%H:%M:%S",
        &tm
    );

    std::snprintf(
        buffer,
        sizeof(buffer),
        "%s.%03dZ",
        date_buffer,
        millis
    );

    return buffer;
}


static enum MHD_Result send_response(
    MHD_Connection* connection,
    unsigned int status,
    const std::string& body,
    const char* content_type
)
{
    MHD_Response* response =
        MHD_create_response_from_buffer(
            body.size(),
            const_cast<char*>(
                body.data()
            ),
            MHD_RESPMEM_MUST_COPY
        );

    if (response == nullptr)
    {
        return MHD_NO;
    }

    MHD_add_response_header(
        response,
        "Content-Type",
        content_type
    );

    enum MHD_Result result =
        MHD_queue_response(
            connection,
            status,
            response
        );

    MHD_destroy_response(
        response
    );

    return result;
}


static enum MHD_Result send_json(
    MHD_Connection* connection,
    unsigned int status,
    const json& value
)
{
    return send_response(
        connection,
        status,
        value.dump(),
        "application/json"
    );
}


static enum MHD_Result health(
    MHD_Connection* connection
)
{
    CassStatement* statement =
        cass_prepared_bind(
            health_prepared
        );

    cass_statement_set_consistency(
        statement,
        CASS_CONSISTENCY_ONE
    );

    cass_statement_bind_string(
        statement,
        0,
        "local"
    );

    CassFuture* future =
        cass_session_execute(
            session,
            statement
        );

    cass_statement_free(
        statement
    );

    if (!future_ok(
            future,
            "health query failed"
        ))
    {
        cass_future_free(
            future
        );

        return send_json(
            connection,
            MHD_HTTP_SERVICE_UNAVAILABLE,
            {
                {"status", "database unavailable"}
            }
        );
    }

    cass_future_free(
        future
    );

    return send_json(
        connection,
        MHD_HTTP_OK,
        {
            {"status", "ok"}
        }
    );
}


static enum MHD_Result parent(
    MHD_Connection* connection,
    cass_int64_t id
)
{
    CassStatement* statement =
        cass_prepared_bind(
            parent_prepared
        );

    cass_statement_set_consistency(
        statement,
        CASS_CONSISTENCY_ONE
    );

    cass_statement_bind_int64(
        statement,
        0,
        id
    );

    CassFuture* future =
        cass_session_execute(
            session,
            statement
        );

    cass_statement_free(
        statement
    );

    if (!future_ok(
            future,
            "parent query failed"
        ))
    {
        cass_future_free(
            future
        );

        return send_json(
            connection,
            MHD_HTTP_INTERNAL_SERVER_ERROR,
            {
                {"error", "query failed"}
            }
        );
    }

    const CassResult* result =
        cass_future_get_result(
            future
        );

    cass_future_free(
        future
    );

    if (result == nullptr)
    {
        return send_json(
            connection,
            MHD_HTTP_INTERNAL_SERVER_ERROR,
            {
                {"error", "query failed"}
            }
        );
    }

    const CassRow* row =
        cass_result_first_row(
            result
        );

    if (row == nullptr)
    {
        cass_result_free(
            result
        );

        return send_json(
            connection,
            MHD_HTTP_NOT_FOUND,
            {
                {"error", "parent not found"}
            }
        );
    }

    cass_int64_t created_at =
        get_int64(
            row,
            "created_at"
        );

    json body = {
        {
            "id",
            get_int64(
                row,
                "id"
            )
        },
        {
            "account_number",
            get_int64(
                row,
                "account_number"
            )
        },
        {
            "status",
            get_string(
                row,
                "status"
            )
        },
        {
            "created_at",
            timestamp_to_iso(
                created_at
            )
        },
        {
            "payload",
            get_string(
                row,
                "payload"
            )
        }
    };

    cass_result_free(
        result
    );

    return send_json(
        connection,
        MHD_HTTP_OK,
        body
    );
}


static enum MHD_Result request_handler(
    void*,
    MHD_Connection* connection,
    const char* url,
    const char* method,
    const char*,
    const char*,
    size_t* upload_data_size,
    void** con_cls
)
{
    static int marker;

    if (*con_cls == nullptr)
    {
        *con_cls = &marker;

        return MHD_YES;
    }

    *con_cls = nullptr;

    if (
        std::strcmp(
            method,
            "GET"
        ) != 0
    )
    {
        return send_json(
            connection,
            MHD_HTTP_METHOD_NOT_ALLOWED,
            {
                {"error", "method not allowed"}
            }
        );
    }

    if (
        *upload_data_size != 0
    )
    {
        *upload_data_size = 0;

        return MHD_YES;
    }

    std::string path(url);

    if (path == "/health")
    {
        return health(
            connection
        );
    }

    const std::string prefix =
        "/parent/";

    if (
        path.rfind(
            prefix,
            0
        ) == 0
    )
    {
        std::string id_text =
            path.substr(
                prefix.size()
            );

        if (id_text.empty())
        {
            return send_json(
                connection,
                MHD_HTTP_BAD_REQUEST,
                {
                    {"error", "invalid parent id"}
                }
            );
        }

        try
        {
            size_t consumed = 0;

            long long value =
                std::stoll(
                    id_text,
                    &consumed
                );

            if (
                consumed !=
                id_text.size()
            )
            {
                throw std::invalid_argument(
                    "invalid id"
                );
            }

            return parent(
                connection,
                static_cast<cass_int64_t>(
                    value
                )
            );
        }
        catch (...)
        {
            return send_json(
                connection,
                MHD_HTTP_BAD_REQUEST,
                {
                    {"error", "invalid parent id"}
                }
            );
        }
    }

    return send_json(
        connection,
        MHD_HTTP_NOT_FOUND,
        {
            {"error", "not found"}
        }
    );
}


static const CassPrepared* prepare_query(
    const char* query,
    const char* label
)
{
    CassFuture* future =
        cass_session_prepare(
            session,
            query
        );

    if (!future_ok(
            future,
            label
        ))
    {
        cass_future_free(
            future
        );

        return nullptr;
    }

    const CassPrepared* prepared =
        cass_future_get_prepared(
            future
        );

    cass_future_free(
        future
    );

    return prepared;
}


static void shutdown_handler(int)
{
    running = false;
}


int main()
{
    const char* host =
        std::getenv(
            "CASSANDRA_HOST"
        );

    if (
        host == nullptr ||
        *host == '\0'
    )
    {
        host =
            "benchmark_cassandra";
    }

    cluster =
        cass_cluster_new();

    session =
        cass_session_new();

    cass_cluster_set_contact_points(
        cluster,
        host
    );

    cass_cluster_set_port(
        cluster,
        9042
    );

    CassFuture* connect_future =
        cass_session_connect_keyspace(
            session,
            cluster,
            "benchmark"
        );

    if (!future_ok(
            connect_future,
            "Cassandra connection failed"
        ))
    {
        cass_future_free(
            connect_future
        );

        cass_session_free(
            session
        );

        cass_cluster_free(
            cluster
        );

        return 1;
    }

    cass_future_free(
        connect_future
    );

    parent_prepared =
        prepare_query(
            R"(
                SELECT
                    id,
                    account_number,
                    status,
                    created_at,
                    payload
                FROM parent_by_id
                WHERE id = ?
            )",
            "parent prepare failed"
        );

    health_prepared =
        prepare_query(
            R"(
                SELECT release_version
                FROM system.local
                WHERE key = ?
            )",
            "health prepare failed"
        );

    if (
        parent_prepared == nullptr ||
        health_prepared == nullptr
    )
    {
        return 1;
    }

    MHD_Daemon* daemon =
        MHD_start_daemon(
            MHD_USE_INTERNAL_POLLING_THREAD,
            8080,
            nullptr,
            nullptr,
            &request_handler,
            nullptr,
            MHD_OPTION_THREAD_POOL_SIZE,
            static_cast<unsigned int>(50),
            MHD_OPTION_CONNECTION_LIMIT,
            static_cast<unsigned int>(4096),
            MHD_OPTION_END
        );

    if (daemon == nullptr)
    {
        std::cerr
            << "Failed to start HTTP server"
            << std::endl;

        return 1;
    }

    std::cout
        << "C++ Cassandra benchmark API listening on :8080"
        << std::endl;

    std::signal(
        SIGINT,
        shutdown_handler
    );

    std::signal(
        SIGTERM,
        shutdown_handler
    );

    while (running)
    {
        std::this_thread::sleep_for(
            std::chrono::milliseconds(
                250
            )
        );
    }

    MHD_stop_daemon(
        daemon
    );

    cass_prepared_free(
        parent_prepared
    );

    cass_prepared_free(
        health_prepared
    );

    CassFuture* close_future =
        cass_session_close(
            session
        );

    cass_future_wait(
        close_future
    );

    cass_future_free(
        close_future
    );

    cass_session_free(
        session
    );

    cass_cluster_free(
        cluster
    );

    return 0;
}
