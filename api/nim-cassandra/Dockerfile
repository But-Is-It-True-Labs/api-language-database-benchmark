FROM nimlang/nim:2.2.4 AS build

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       build-essential \
       cmake \
       git \
       libuv1-dev \
       libssl-dev \
       zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

RUN git clone \
      --depth 1 \
      --branch 2.17.1 \
      https://github.com/apache/cassandra-cpp-driver.git \
      /tmp/cassandra-cpp-driver \
    && cmake \
      -S /tmp/cassandra-cpp-driver \
      -B /tmp/cassandra-cpp-driver/build \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_CXX_STANDARD=11 \
      -DCASS_BUILD_SHARED=ON \
      -DCASS_BUILD_STATIC=OFF \
      -DCASS_BUILD_EXAMPLES=OFF \
      -DCASS_BUILD_TESTS=OFF \
      -DCMAKE_INSTALL_PREFIX=/usr/local \
    && cmake \
      --build /tmp/cassandra-cpp-driver/build \
      --parallel \
    && cmake \
      --install /tmp/cassandra-cpp-driver/build \
    && ldconfig \
    && mkdir -p /tmp/cassandra-runtime \
    && find /usr/local -type f -name 'libcassandra.so*' -exec cp -a {} /tmp/cassandra-runtime/ \;

RUN nimble install -y mummy

WORKDIR /src

COPY cassandra_bridge.h .
COPY cassandra_bridge.c .
COPY main.nim .

RUN cc \
      -O3 \
      -fPIC \
      -shared \
      cassandra_bridge.c \
      -I/usr/local/include \
      -L/usr/local/lib \
      -lcassandra \
      -Wl,-rpath,/usr/local/lib \
      -o /usr/local/lib/libbenchmark_cassandra_bridge.so \
    && ldconfig

RUN nim c \
    -d:release \
    --opt:speed \
    --threads:on \
    --mm:orc \
    --out:/out-benchmark-nim-cassandra-api \
    main.nim


FROM debian:bookworm-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       ca-certificates \
       libuv1 \
       libssl3 \
       zlib1g \
       libstdc++6 \
    && rm -rf /var/lib/apt/lists/*

COPY --from=build \
    /tmp/cassandra-runtime/ \
    /usr/local/lib/

COPY --from=build \
    /usr/local/lib/libbenchmark_cassandra_bridge.so \
    /usr/local/lib/

COPY --from=build \
    /out-benchmark-nim-cassandra-api \
    /usr/local/bin/benchmark-nim-cassandra-api

ENV LD_LIBRARY_PATH=/usr/local/lib

RUN ldconfig

EXPOSE 8080

ENTRYPOINT ["/usr/local/bin/benchmark-nim-cassandra-api"]
