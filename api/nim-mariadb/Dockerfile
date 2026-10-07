FROM nimlang/nim:2.2.4 AS build

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       default-libmysqlclient-dev \
       gcc \
       git \
    && rm -rf /var/lib/apt/lists/*

RUN nimble install -y \
    db_connector \
    mummy

WORKDIR /src

COPY main.nim .

RUN nim c \
    -d:release \
    --opt:speed \
    --threads:on \
    --mm:orc \
    --out:/out-benchmark-nim-api \
    main.nim


FROM debian:bookworm-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       libmariadb3 \
       ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY --from=build \
    /out-benchmark-nim-api \
    /usr/local/bin/benchmark-nim-api

EXPOSE 8080

ENTRYPOINT ["/usr/local/bin/benchmark-nim-api"]
