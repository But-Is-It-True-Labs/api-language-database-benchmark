#ifndef BIIT_MONGO_BRIDGE_H
#define BIIT_MONGO_BRIDGE_H
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif
int benchmark_mongo_health(void);
char *benchmark_mongo_parent(int64_t id);
void benchmark_mongo_free(char *p);
#ifdef __cplusplus
}
#endif
#endif
