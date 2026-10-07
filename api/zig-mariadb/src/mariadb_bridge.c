#include "mariadb_bridge.h"

#include <mysql/mysql.h>
#include <stdio.h>
#include <string.h>

static char g_host[256] = "benchmark_mariadb";
static unsigned int g_port = 3306;
static char g_user[128] = "benchmark";
static char g_password[256] = "benchmark_password";
static char g_database[128] = "benchmark";

static _Thread_local MYSQL *tls_conn = NULL;

static _Thread_local long long p_id = 0;
static _Thread_local long long p_account = 0;
static _Thread_local char p_status[128];
static _Thread_local char p_created_at[128];
static _Thread_local char p_payload[2048];

static void copy_text(char *dst, size_t size, const char *src) {
    if (size == 0) return;
    if (!src) {
        dst[0] = '\0';
        return;
    }
    snprintf(dst, size, "%s", src);
}

int mariadb_bridge_init(
    const char *host,
    unsigned int port,
    const char *user,
    const char *password,
    const char *database
) {
    copy_text(g_host, sizeof(g_host), host);
    g_port = port;
    copy_text(g_user, sizeof(g_user), user);
    copy_text(g_password, sizeof(g_password), password);
    copy_text(g_database, sizeof(g_database), database);
    return 0;
}

static MYSQL *get_conn(void) {
    if (tls_conn) return tls_conn;

    tls_conn = mysql_init(NULL);
    if (!tls_conn) return NULL;

    if (!mysql_real_connect(
        tls_conn,
        g_host,
        g_user,
        g_password,
        g_database,
        g_port,
        NULL,
        0
    )) {
        mysql_close(tls_conn);
        tls_conn = NULL;
        return NULL;
    }

    return tls_conn;
}

int mariadb_bridge_health(void) {
    MYSQL *conn = get_conn();
    if (!conn) return -1;

    if (mysql_query(conn, "SELECT 1") != 0) return -1;

    MYSQL_RES *res = mysql_store_result(conn);
    if (!res) return -1;

    mysql_free_result(res);
    return 1;
}

int mariadb_bridge_parent(long long id) {
    MYSQL *conn = get_conn();
    if (!conn) return -1;

    char sql[256];
    snprintf(
        sql,
        sizeof(sql),
        "SELECT id, account_number, status, created_at, payload "
        "FROM benchmark_parent WHERE id = %lld",
        id
    );

    if (mysql_query(conn, sql) != 0) return -1;

    MYSQL_RES *res = mysql_store_result(conn);
    if (!res) return -1;

    MYSQL_ROW row = mysql_fetch_row(res);
    if (!row) {
        mysql_free_result(res);
        return 0;
    }

    p_id = row[0] ? atoll(row[0]) : 0;
    p_account = row[1] ? atoll(row[1]) : 0;
    copy_text(p_status, sizeof(p_status), row[2]);
    copy_text(p_created_at, sizeof(p_created_at), row[3]);
    copy_text(p_payload, sizeof(p_payload), row[4]);

    mysql_free_result(res);
    return 1;
}

long long mariadb_bridge_parent_id(void) { return p_id; }
long long mariadb_bridge_parent_account_number(void) { return p_account; }
const char *mariadb_bridge_parent_status(void) { return p_status; }
const char *mariadb_bridge_parent_created_at(void) { return p_created_at; }
const char *mariadb_bridge_parent_payload(void) { return p_payload; }
