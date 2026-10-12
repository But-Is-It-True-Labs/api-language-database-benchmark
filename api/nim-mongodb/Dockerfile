FROM nimlang/nim:2.2.4
RUN apt-get update && apt-get install -y --no-install-recommends gcc git pkg-config libmongoc-dev && rm -rf /var/lib/apt/lists/*
RUN nimble install -y mummy
WORKDIR /src
COPY main.nim mongo_bridge.c mongo_bridge.h ./
RUN cc -O3 -fPIC -shared mongo_bridge.c -o /usr/local/lib/libbenchmark_mongo_bridge.so $(pkg-config --cflags --libs libmongoc-1.0) -lpthread && ldconfig
RUN nim c -d:release --threads:on --mm:orc --opt:speed --out:/usr/local/bin/benchmark-nim-mongodb-api main.nim
EXPOSE 8080
ENTRYPOINT ["/usr/local/bin/benchmark-nim-mongodb-api"]
