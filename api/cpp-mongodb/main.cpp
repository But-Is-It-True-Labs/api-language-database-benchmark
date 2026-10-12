#include <microhttpd.h>
#include <string>
#include <cstring>
#include <thread>
#include <chrono>
#include "mongo_bridge.h"
static enum MHD_Result send(struct MHD_Connection *conn,unsigned code,const std::string &s){auto *resp=MHD_create_response_from_buffer(s.size(),(void*)s.data(),MHD_RESPMEM_MUST_COPY);MHD_add_response_header(resp,"Content-Type","application/json");auto out=MHD_queue_response(conn,code,resp);MHD_destroy_response(resp);return out;}
static enum MHD_Result handle(void*,struct MHD_Connection *conn,const char *url,const char *method,const char*,const char*,size_t*,void**){
 if(strcmp(method,"GET"))return send(conn,405,"{\"error\":\"method not allowed\"}");
 std::string path(url);
 if(path=="/health")return benchmark_mongo_health()?send(conn,200,"{\"status\":\"ok\"}"):send(conn,503,"{\"status\":\"database unavailable\"}");
 if(path.rfind("/parent/",0)==0){auto id_str=path.substr(8);try{size_t pos;long long id=std::stoll(id_str,&pos);if(pos!=id_str.size())return send(conn,400,"{\"error\":\"invalid id\"}");char *json=benchmark_mongo_parent(id);if(!json)return send(conn,404,"{\"error\":\"parent not found\"}");std::string result(json);benchmark_mongo_free(json);return send(conn,200,result);}catch(...){return send(conn,400,"{\"error\":\"invalid id\"}");}}
 return send(conn,404,"{\"error\":\"not found\"}");
}
int main(){auto *s=MHD_start_daemon(MHD_USE_INTERNAL_POLLING_THREAD|MHD_USE_THREAD_PER_CONNECTION,8080,nullptr,nullptr,&handle,nullptr,MHD_OPTION_END);if(!s)return 1;while(true)std::this_thread::sleep_for(std::chrono::hours(1));}
