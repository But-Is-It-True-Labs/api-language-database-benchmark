#include "mongo_bridge.h"
#include <mongoc/mongoc.h>
#include <bson/bson.h>
#include <pthread.h>
#include <stdlib.h>
#include <time.h>
#include <stdio.h>
#include <string.h>
static pthread_once_t once=PTHREAD_ONCE_INIT;
static mongoc_client_pool_t *pool=NULL;
static void setup(void){mongoc_init();const char *s=getenv("MONGO_URL");if(!s){fprintf(stderr,"MONGO_URL missing\n");return;}mongoc_uri_t *u=mongoc_uri_new(s);if(!u)return;pool=mongoc_client_pool_new(u);mongoc_uri_destroy(u);}
static mongoc_client_t *acquire(void){pthread_once(&once,setup);return pool?mongoc_client_pool_pop(pool):NULL;}
int benchmark_mongo_health(void){mongoc_client_t *c=acquire();if(!c)return 0; bson_t cmd=BSON_INITIALIZER;BSON_APPEND_INT32(&cmd,"ping",1);bson_error_t err;bool ok=mongoc_client_command_simple(c,"admin",&cmd,NULL,NULL,&err);bson_destroy(&cmd);mongoc_client_pool_push(pool,c);return ok?1:0;}
char *benchmark_mongo_parent(int64_t id){
 mongoc_client_t *c=acquire();if(!c)return NULL;
 mongoc_collection_t *col=mongoc_client_get_collection(c,"benchmark","benchmark_parent");
 bson_t q=BSON_INITIALIZER;BSON_APPEND_INT64(&q,"_id",id);
 mongoc_cursor_t *cur=mongoc_collection_find_with_opts(col,&q,NULL,NULL);const bson_t *found=NULL;
 char *result=NULL;
 if(mongoc_cursor_next(cur,&found)){
  bson_iter_t it;int64_t account=0;const char *status="",*payload="";int64_t dt=0;
  if(bson_iter_init_find(&it,found,"account_number")) account=bson_iter_as_int64(&it);
  if(bson_iter_init_find(&it,found,"status")) status=bson_iter_utf8(&it,NULL);
  if(bson_iter_init_find(&it,found,"payload")) payload=bson_iter_utf8(&it,NULL);
  if(bson_iter_init_find(&it,found,"created_at") && BSON_ITER_HOLDS_DATE_TIME(&it)) dt=bson_iter_date_time(&it);
  time_t seconds=(time_t)(dt/1000);struct tm utc;gmtime_r(&seconds,&utc);char timestamp[32];strftime(timestamp,sizeof(timestamp),"%Y-%m-%dT%H:%M:%S",&utc);
  bson_t out=BSON_INITIALIZER;
  BSON_APPEND_INT64(&out,"id",id);BSON_APPEND_INT64(&out,"account_number",account);
  BSON_APPEND_UTF8(&out,"status",status);
  char iso[40];snprintf(iso,sizeof(iso),"%s.%03lldZ",timestamp,(long long)(dt%1000));BSON_APPEND_UTF8(&out,"created_at",iso);
  BSON_APPEND_UTF8(&out,"payload",payload);
  char *b=bson_as_relaxed_extended_json(&out,NULL);
  if(b){result=strdup(b);bson_free(b);}bson_destroy(&out);
 }
 mongoc_cursor_destroy(cur);bson_destroy(&q);mongoc_collection_destroy(col);mongoc_client_pool_push(pool,c);return result;
}
void benchmark_mongo_free(char *p){free(p);}
