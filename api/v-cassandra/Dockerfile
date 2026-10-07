FROM thevlang/vlang AS build

RUN apk add --no-cache \
    build-base \
    cmake \
    git \
    linux-headers \
    libuv-dev \
    openssl-dev \
    zlib-dev \
    gc-dev

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
      --install /tmp/cassandra-cpp-driver/build

WORKDIR /src

COPY cassandra_bridge.h \
     /usr/local/include/cassandra_bridge.h

COPY cassandra_bridge.c .

RUN cc \
      -O3 \
      -fPIC \
      -shared \
      cassandra_bridge.c \
      -I/usr/local/include \
      -L/usr/local/lib \
      -lcassandra \
      -Wl,-rpath,/usr/local/lib \
      -o /usr/local/lib/libbenchmark_cassandra_bridge.so

COPY main.v .

RUN v \
    -d new_veb \
    -prod \
    -cc gcc \
    -o /out-benchmark-v-cassandra-api \
    main.v


FROM alpine:3.20

RUN apk add --no-cache \
    libuv \
    openssl \
    zlib \
    gc \
    libgcc \
    libstdc++

COPY --from=build \
    /usr/local/lib/libcassandra.so* \
    /usr/local/lib/

COPY --from=build \
    /usr/local/lib/libbenchmark_cassandra_bridge.so \
    /usr/local/lib/

COPY --from=build \
    /out-benchmark-v-cassandra-api \
    /usr/local/bin/benchmark-v-cassandra-api

ENV LD_LIBRARY_PATH=/usr/local/lib

EXPOSE 8080

ENTRYPOINT ["/usr/local/bin/benchmark-v-cassandra-api"]
