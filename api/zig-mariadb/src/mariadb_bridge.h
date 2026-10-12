#ifndef MARIADB_BRIDGE_H
#define MARIADB_BRIDGE_H

int mariadb_bridge_init(
    const char *host,
    unsigned int port,
    const char *user,
    const char *password,
    const char *database
);

int mariadb_bridge_health(void);
int mariadb_bridge_parent(long long id);

long long mariadb_bridge_parent_id(void);
long long mariadb_bridge_parent_account_number(void);
const char *mariadb_bridge_parent_status(void);
const char *mariadb_bridge_parent_created_at(void);
const char *mariadb_bridge_parent_payload(void);

#endif
