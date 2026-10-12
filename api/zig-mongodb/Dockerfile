FROM kassany/alpine-ziglang:0.16.0
USER root
RUN apk add --no-cache build-base mongo-c-driver-dev linux-headers
WORKDIR /src
COPY build.zig build.zig.zon ./
COPY src ./src
COPY mongo_bridge.c mongo_bridge.h ./
RUN cc -O3 -fPIC -shared mongo_bridge.c -o /usr/local/lib/libbenchmark_mongo_bridge.so $(pkg-config --cflags --libs libmongoc-1.0) -lpthread
RUN zig build --fetch && zig build -Doptimize=ReleaseFast
ENV LD_LIBRARY_PATH=/usr/local/lib
EXPOSE 8080
ENTRYPOINT ["/src/zig-out/bin/benchmark-zig-mongodb-api"]
