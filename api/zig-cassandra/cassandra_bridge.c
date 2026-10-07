#include "cassandra_bridge.h"

#include <cassandra.h>

#include <stdio.h>
#include <string.h>
#include <time.h>

typedef struct {
    int64_t id;
    int64_t account_number;
    char status[128];
    char created_at[64];
    char payload[4096];
} BcParent;

static CassCluster *cluster = NULL;
static CassSession *session = NULL;
static const CassPrepared *parent_prepared = NULL;
static const CassPrepared *health_prepared = NULL;

static _Thread_local BcParent tls_parent;

static int future_ok(CassFuture *future) {
    cass_future_wait(future);

    if (cass_future_error_code(future) != CASS_OK) {
        const char *message = NULL;
        size_t message_len = 0;

        cass_future_error_message(
            future,
            &message,
            &message_len
        );

        if (message != NULL && message_len > 0) {
            fprintf(
                stderr,
                "Cassandra error: %.*s\n",
                (int)message_len,
                message
            );
        }

        return 0;
    }

    return 1;
}

static int copy_text(
    const CassRow *row,
    const char *column,
    char *dest,
    size_t dest_size
) {
    const CassValue *value =
        cass_row_get_column_by_name(
            row,
            column
        );

    const char *src = NULL;
    size_t src_len = 0;

    if (
        value == NULL ||
        cass_value_is_null(value) ||
        cass_value_get_string(
            value,
            &src,
            &src_len
        ) != CASS_OK
    ) {
        return 0;
    }

    if (dest_size == 0) {
        return 0;
    }

    if (src_len >= dest_size) {
        src_len = dest_size - 1;
    }

    memcpy(
        dest,
        src,
        src_len
    );

    dest[src_len] = '\0';

    return 1;
}

static void timestamp_to_iso(
    int64_t milliseconds,
    char *dest,
    size_t dest_size
) {
    time_t seconds =
        (time_t)(milliseconds / 1000);

    int millis =
        (int)(milliseconds % 1000);

    if (millis < 0) {
        millis += 1000;
        --seconds;
    }

    struct tm utc_tm;

    gmtime_r(
        &seconds,
        &utc_tm
    );

    if (millis == 0) {
        strftime(
            dest,
            dest_size,
            "%Y-%m-%dT%H:%M:%SZ",
            &utc_tm
        );

        return;
    }

    char base[48];

    strftime(
        base,
        sizeof(base),
        "%Y-%m-%dT%H:%M:%S",
        &utc_tm
    );

    snprintf(
        dest,
        dest_size,
        "%s.%03dZ",
        base,
        millis
    );
}

static const CassPrepared *prepare_query(
    const char *query
) {
    CassFuture *future =
        cass_session_prepare(
            session,
            query
        );

    if (!future_ok(future)) {
        cass_future_free(future);
        return NULL;
    }

    const CassPrepared *prepared =
        cass_future_get_prepared(
            future
        );

    cass_future_free(future);

    return prepared;
}

int bc_init(const char *host) {
    cluster =
        cass_cluster_new();

    session =
        cass_session_new();

    if (
        cluster == NULL ||
        session == NULL
    ) {
        return -1;
    }

    if (
        cass_cluster_set_contact_points(
            cluster,
            host
        ) != CASS_OK
    ) {
        return -1;
    }

    cass_cluster_set_port(
        cluster,
        9042
    );

    CassFuture *connect_future =
        cass_session_connect_keyspace(
            session,
            cluster,
            "benchmark"
        );

    if (!future_ok(connect_future)) {
        cass_future_free(
            connect_future
        );

        return -1;
    }

    cass_future_free(
        connect_future
    );

    parent_prepared =
        prepare_query(
            "SELECT id, account_number, status, created_at, payload "
            "FROM parent_by_id "
            "WHERE id = ?"
        );

    health_prepared =
        prepare_query(
            "SELECT release_version "
            "FROM system.local"
        );

    if (
        parent_prepared == NULL ||
        health_prepared == NULL
    ) {
        return -1;
    }

    return 0;
}

int bc_health(void) {
    CassStatement *statement =
        cass_prepared_bind(
            health_prepared
        );

    if (statement == NULL) {
        return -1;
    }

    cass_statement_set_consistency(
        statement,
        CASS_CONSISTENCY_ONE
    );

    CassFuture *future =
        cass_session_execute(
            session,
            statement
        );

    cass_statement_free(
        statement
    );

    int ok =
        future_ok(
            future
        );

    cass_future_free(
        future
    );

    return ok ? 0 : -1;
}

int bc_get_parent(int64_t id) {
    CassStatement *statement =
        cass_prepared_bind(
            parent_prepared
        );

    if (statement == NULL) {
        return -1;
    }

    cass_statement_set_consistency(
        statement,
        CASS_CONSISTENCY_ONE
    );

    if (
        cass_statement_bind_int64(
            statement,
            0,
            (cass_int64_t)id
        ) != CASS_OK
    ) {
        cass_statement_free(
            statement
        );

        return -1;
    }

    CassFuture *future =
        cass_session_execute(
            session,
            statement
        );

    cass_statement_free(
        statement
    );

    if (!future_ok(future)) {
        cass_future_free(
            future
        );

        return -1;
    }

    const CassResult *result =
        cass_future_get_result(
            future
        );

    cass_future_free(
        future
    );

    if (result == NULL) {
        return -1;
    }

    const CassRow *row =
        cass_result_first_row(
            result
        );

    if (row == NULL) {
        cass_result_free(
            result
        );

        return 1;
    }

    memset(
        &tls_parent,
        0,
        sizeof(tls_parent)
    );

    const CassValue *id_value =
        cass_row_get_column_by_name(
            row,
            "id"
        );

    const CassValue *account_value =
        cass_row_get_column_by_name(
            row,
            "account_number"
        );

    const CassValue *created_value =
        cass_row_get_column_by_name(
            row,
            "created_at"
        );

    cass_int64_t parsed_id = 0;
    cass_int64_t parsed_account = 0;
    cass_int64_t parsed_created = 0;

    if (
        id_value == NULL ||
        account_value == NULL ||
        created_value == NULL ||
        cass_value_get_int64(
            id_value,
            &parsed_id
        ) != CASS_OK ||
        cass_value_get_int64(
            account_value,
            &parsed_account
        ) != CASS_OK ||
        cass_value_get_int64(
            created_value,
            &parsed_created
        ) != CASS_OK ||
        !copy_text(
            row,
            "status",
            tls_parent.status,
            sizeof(tls_parent.status)
        ) ||
        !copy_text(
            row,
            "payload",
            tls_parent.payload,
            sizeof(tls_parent.payload)
        )
    ) {
        cass_result_free(
            result
        );

        return -1;
    }

    tls_parent.id =
        (int64_t)parsed_id;

    tls_parent.account_number =
        (int64_t)parsed_account;

    timestamp_to_iso(
        (int64_t)parsed_created,
        tls_parent.created_at,
        sizeof(tls_parent.created_at)
    );

    cass_result_free(
        result
    );

    return 0;
}

int64_t bc_parent_id(void) {
    return tls_parent.id;
}

int64_t bc_parent_account_number(void) {
    return tls_parent.account_number;
}

const char *bc_parent_status(void) {
    return tls_parent.status;
}

const char *bc_parent_created_at(void) {
    return tls_parent.created_at;
}

const char *bc_parent_payload(void) {
    return tls_parent.payload;
}

void bc_shutdown(void) {
    if (parent_prepared != NULL) {
        cass_prepared_free(
            parent_prepared
        );

        parent_prepared = NULL;
    }

    if (health_prepared != NULL) {
        cass_prepared_free(
            health_prepared
        );

        health_prepared = NULL;
    }

    if (session != NULL) {
        CassFuture *close_future =
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

        session = NULL;
    }

    if (cluster != NULL) {
        cass_cluster_free(
            cluster
        );

        cluster = NULL;
    }
}
