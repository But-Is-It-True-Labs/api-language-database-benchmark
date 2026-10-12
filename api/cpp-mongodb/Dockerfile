FROM debian:bookworm
RUN apt-get update && apt-get install -y --no-install-recommends g++ gcc pkg-config libmongoc-dev libmicrohttpd-dev ca-certificates && rm -rf /var/lib/apt/lists/*
WORKDIR /src
COPY main.cpp mongo_bridge.c mongo_bridge.h ./
RUN cc -O3 -c mongo_bridge.c $(pkg-config --cflags libmongoc-1.0) -o bridge.o && g++ -O3 main.cpp bridge.o -o /usr/local/bin/benchmark-cpp-mongodb-api $(pkg-config --libs libmongoc-1.0) -lmicrohttpd -lpthread
EXPOSE 8080
ENTRYPOINT ["/usr/local/bin/benchmark-cpp-mongodb-api"]
