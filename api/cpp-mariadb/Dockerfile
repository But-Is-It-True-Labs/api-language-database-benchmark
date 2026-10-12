FROM debian:bookworm AS build

RUN apt-get update \
    && apt-get install -y \
       build-essential \
       cmake \
       libmariadb-dev \
       libmicrohttpd-dev \
       nlohmann-json3-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src

COPY CMakeLists.txt .
COPY main.cpp .

RUN cmake \
      -S . \
      -B build \
      -DCMAKE_BUILD_TYPE=Release \
    && cmake \
      --build build \
      --parallel


FROM debian:bookworm-slim

RUN apt-get update \
    && apt-get install -y \
       libmariadb3 \
       libmicrohttpd12 \
    && rm -rf /var/lib/apt/lists/*

COPY --from=build \
    /src/build/benchmark-cpp-api \
    /usr/local/bin/benchmark-cpp-api

EXPOSE 8080

ENTRYPOINT ["/usr/local/bin/benchmark-cpp-api"]
