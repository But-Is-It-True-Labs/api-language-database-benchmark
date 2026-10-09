#include <microhttpd.h>
#include <mysql.h>
#include <nlohmann/json.hpp>

#include <chrono>
#include <condition_variable>
#include <cstdlib>
#include <cstring>
#include <iostream>
#include <memory>
#include <mutex>
#include <queue>
#include <string>
#include <thread>

using json = nlohmann::json;

class MariaPool {
public:
    MariaPool(const char* host, unsigned int port, const char* user, const char* password, const char* database, std::size_t size) {
        for (std::size_t i = 0; i < size; ++i) {
            MYSQL* connection = mysql_init(nullptr);
            if (!connection || !mysql_real_connect(connection, host, user, password, database, port, nullptr, 0)) {
                std::string error = connection ? mysql_error(connection) : "mysql_init failed";
                if (connection) mysql_close(connection);
                throw std::runtime_error(error);
            }
            connections_.push(connection);
        }
    }

    ~MariaPool() {
        while (!connections_.empty()) {
            mysql_close(connections_.front());
            connections_.pop();
        }
    }

    MYSQL* acquire() {
        std::unique_lock lock(mutex_);
        cv_.wait(lock, [&] { return !connections_.empty(); });
        MYSQL* c = connections_.front();
        connections_.pop();
        return c;
    }

    void release(MYSQL* c) {
        {
            std::lock_guard lock(mutex_);
            connections_.push(c);
        }
        cv_.notify_one();
    }

private:
    std::queue<MYSQL*> connections_;
    std::mutex mutex_;
    std::condition_variable cv_;
};

static std::unique_ptr<MariaPool> db;

static int send_json(MHD_Connection* connection, unsigned int status, const json& value) {
    std::string body = value.dump();
    MHD_Response* response = MHD_create_response_from_buffer(body.size(), const_cast<char*>(body.data()), MHD_RESPMEM_MUST_COPY);
    MHD_add_response_header(response, "Content-Type", "application/json");
    int result = MHD_queue_response(connection, status, response);
    MHD_destroy_response(response);
    return result;
}

static int send_text(MHD_Connection* connection, unsigned int status, const std::string& body) {
    MHD_Response* response = MHD_create_response_from_buffer(body.size(), const_cast<char*>(body.data()), MHD_RESPMEM_MUST_COPY);
    int result = MHD_queue_response(connection, status, response);
    MHD_destroy_response(response);
    return result;
}

static MYSQL_RES* run_query(MYSQL* connection, const std::string& sql) {
    if (mysql_query(connection, sql.c_str()) != 0) return nullptr;
    return mysql_store_result(connection);
}

static std::string numeric_id(const std::string& input) {
    std::size_t used = 0;
    long long id = std::stoll(input, &used);
    if (used != input.size()) throw std::runtime_error("invalid id");
    return std::to_string(id);
}

static json parent_json(MYSQL_ROW row) {
    return {
        {"id", std::stoll(row[0])},
        {"account_number", std::stoll(row[1])},
        {"status", row[2] ? row[2] : ""},
        {"created_at", row[3] ? row[3] : ""},
        {"payload", row[4] ? row[4] : ""}
    };
}

static json child_json(MYSQL_ROW row) {
    return {
        {"id", std::stoll(row[0])},
        {"parent_id", std::stoll(row[1])},
        {"sequence_number", std::stoi(row[2])},
        {"value_number", std::stoi(row[3])},
        {"payload", row[4] ? row[4] : ""}
    };
}

static json event_json(MYSQL_ROW row) {
    return {
        {"id", std::stoll(row[0])},
        {"parent_id", std::stoll(row[1])},
        {"event_type", row[2] ? row[2] : ""},
        {"event_time", row[3] ? row[3] : ""},
        {"payload", row[4] ? row[4] : ""}
    };
}

static int handle_get(MHD_Connection* connection, const std::string& path) {
    MYSQL* maria = db->acquire();
    try {
        if (path == "/health") {
            MYSQL_RES* result = run_query(maria, "SELECT 1");
            bool ok = result != nullptr;
            if (result) mysql_free_result(result);
            db->release(maria);
            return send_json(connection, ok ? 200 : 503, {{"status", ok ? "ok" : "database unavailable"}});
        }

        const std::string parent_prefix = "/parent/";

        if (path.starts_with(parent_prefix) && path.find('/', parent_prefix.size()) == std::string::npos) {
            std::string id = numeric_id(path.substr(parent_prefix.size()));
            MYSQL_RES* result = run_query(maria,
                "SELECT id, account_number, status, created_at, payload FROM benchmark_parent WHERE id = " + id);
            if (!result) { db->release(maria); return send_text(connection, 500, "query failed"); }
            MYSQL_ROW row = mysql_fetch_row(result);
            if (!row) { mysql_free_result(result); db->release(maria); return send_text(connection, 404, "parent not found"); }
            json body = parent_json(row);
            mysql_free_result(result);
            db->release(maria);
            return send_json(connection, 200, body);
        }

        auto suffix_id = [&](const std::string& suffix) -> std::string {
            if (!path.starts_with(parent_prefix) || !path.ends_with(suffix)) return "";
            auto end = path.size() - suffix.size();
            return numeric_id(path.substr(parent_prefix.size(), end - parent_prefix.size()));
        };

        std::string id = suffix_id("/children");
        if (!id.empty()) {
            MYSQL_RES* result = run_query(maria,
                "SELECT id, parent_id, sequence_number, value_number, payload FROM benchmark_child WHERE parent_id = " + id + " ORDER BY id");
            if (!result) { db->release(maria); return send_text(connection, 500, "query failed"); }
            json body = json::array();
            while (MYSQL_ROW row = mysql_fetch_row(result)) body.push_back(child_json(row));
            mysql_free_result(result);
            db->release(maria);
            return send_json(connection, 200, body);
        }

        id = suffix_id("/events");
        if (!id.empty()) {
            MYSQL_RES* result = run_query(maria,
                "SELECT id, parent_id, event_type, event_time, payload FROM benchmark_event WHERE parent_id = " + id + " ORDER BY event_time DESC, id DESC LIMIT 20");
            if (!result) { db->release(maria); return send_text(connection, 500, "query failed"); }
            json body = json::array();
            while (MYSQL_ROW row = mysql_fetch_row(result)) body.push_back(event_json(row));
            mysql_free_result(result);
            db->release(maria);
            return send_json(connection, 200, body);
        }

        id = suffix_id("/bundle");
        if (!id.empty()) {
            MYSQL_RES* parents = run_query(maria,
                "SELECT id, account_number, status, created_at, payload FROM benchmark_parent WHERE id = " + id);
            if (!parents) { db->release(maria); return send_text(connection, 500, "parent query failed"); }
            MYSQL_ROW prow = mysql_fetch_row(parents);
            if (!prow) { mysql_free_result(parents); db->release(maria); return send_text(connection, 404, "parent not found"); }
            json parent = parent_json(prow);
            mysql_free_result(parents);

            MYSQL_RES* children = run_query(maria,
                "SELECT id, parent_id, sequence_number, value_number, payload FROM benchmark_child WHERE parent_id = " + id + " ORDER BY id");
            if (!children) { db->release(maria); return send_text(connection, 500, "child query failed"); }
            json child_rows = json::array();
            while (MYSQL_ROW row = mysql_fetch_row(children)) child_rows.push_back(child_json(row));
            mysql_free_result(children);

            MYSQL_RES* events = run_query(maria,
                "SELECT id, parent_id, event_type, event_time, payload FROM benchmark_event WHERE parent_id = " + id + " ORDER BY event_time DESC, id DESC LIMIT 20");
            if (!events) { db->release(maria); return send_text(connection, 500, "event query failed"); }
            json event_rows = json::array();
            while (MYSQL_ROW row = mysql_fetch_row(events)) event_rows.push_back(event_json(row));
            mysql_free_result(events);

            db->release(maria);
            return send_json(connection, 200, {{"parent", parent}, {"children", child_rows}, {"events", event_rows}});
        }

        const std::string account_prefix = "/account/";
        const std::string account_suffix = "/parents";
        if (path.starts_with(account_prefix) && path.ends_with(account_suffix)) {
            auto end = path.size() - account_suffix.size();
            std::string account = numeric_id(path.substr(account_prefix.size(), end - account_prefix.size()));
            MYSQL_RES* result = run_query(maria,
                "SELECT id, account_number, status, created_at, payload FROM benchmark_parent WHERE account_number = " + account + " ORDER BY id LIMIT 50");
            if (!result) { db->release(maria); return send_text(connection, 500, "query failed"); }
            json body = json::array();
            while (MYSQL_ROW row = mysql_fetch_row(result)) body.push_back(parent_json(row));
            mysql_free_result(result);
            db->release(maria);
            return send_json(connection, 200, body);
        }

        db->release(maria);
        return send_text(connection, 404, "not found");
    } catch (...) {
        db->release(maria);
        return send_text(connection, 500, "internal server error");
    }
}

static MHD_Result request_handler(void*, MHD_Connection* connection, const char* url, const char* method, const char*, const char*, size_t*, void**) {
    if (std::strcmp(method, "GET") == 0) {
        return static_cast<MHD_Result>(handle_get(connection, url));
    }
    return static_cast<MHD_Result>(send_text(connection, 405, "method not allowed"));
}

static const char* env_or(const char* name, const char* fallback) {
    const char* value = std::getenv(name);
    return (value && *value) ? value : fallback;
}

int main() {
    const char* host = env_or("MYSQLHOST", "benchmark_mariadb");
    unsigned int port = static_cast<unsigned int>(std::stoul(env_or("MYSQLPORT", "3306")));
    const char* user = env_or("MYSQLUSER", "benchmark");
    const char* password = env_or("MYSQLPASSWORD", "benchmark_password");
    const char* database = env_or("MYSQLDATABASE", "benchmark");

    try {
        db = std::make_unique<MariaPool>(host, port, user, password, database, 50);
    } catch (const std::exception& error) {
        std::cerr << "Database connection failed: " << error.what() << '\n';
        return 1;
    }

    MHD_Daemon* daemon = MHD_start_daemon(
        MHD_USE_INTERNAL_POLLING_THREAD | MHD_USE_THREAD_PER_CONNECTION,
        8080, nullptr, nullptr, &request_handler, nullptr, MHD_OPTION_END
    );
    if (!daemon) {
        std::cerr << "Failed to start HTTP server\n";
        return 1;
    }

    std::cout << "C++ MariaDB benchmark API listening on :8080\n";
    while (true) std::this_thread::sleep_for(std::chrono::hours(24));
    MHD_stop_daemon(daemon);
    return 0;
}
