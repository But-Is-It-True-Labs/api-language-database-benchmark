FROM thevlang/vlang
RUN apk add --no-cache build-base mongo-c-driver-dev gc-dev
WORKDIR /src
COPY main.v mongo_bridge.c mongo_bridge.h ./
RUN cc -O3 -fPIC -shared mongo_bridge.c -o /usr/local/lib/libbenchmark_mongo_bridge.so $(pkg-config --cflags --libs libmongoc-1.0) -lpthread
RUN v -d new_veb -prod -cc gcc -o /usr/local/bin/benchmark-v-mongodb-api main.v
ENV LD_LIBRARY_PATH=/usr/local/lib
EXPOSE 8080
ENTRYPOINT ["/usr/local/bin/benchmark-v-mongodb-api"]
