#ifndef BENCHMARK_CASSANDRA_BRIDGE_H
#define BENCHMARK_CASSANDRA_BRIDGE_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

int bc_init(const char *host);
int bc_health(void);
int bc_get_parent(int64_t id);

int64_t bc_parent_id(void);
int64_t bc_parent_account_number(void);
const char *bc_parent_status(void);
const char *bc_parent_created_at(void);
const char *bc_parent_payload(void);

void bc_shutdown(void);

#ifdef __cplusplus
}
#endif

#endif
