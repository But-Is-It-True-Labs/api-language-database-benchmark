FROM haskell:9.10.3-bookworm AS build

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       build-essential \
       libssl-dev \
       pkg-config \
       zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src

COPY benchmark-haskell-cassandra-api.cabal .

RUN cabal update \
    && cabal build \
       --only-dependencies \
       -j12

COPY Main.hs .

RUN cabal build \
       -j12 \
    && mkdir -p /out \
    && cp \
       "$(cabal list-bin exe:benchmark-haskell-cassandra-api)" \
       /out/benchmark-haskell-cassandra-api


FROM debian:bookworm-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       ca-certificates \
       libssl3 \
       zlib1g \
    && rm -rf /var/lib/apt/lists/*

COPY --from=build \
    /out/benchmark-haskell-cassandra-api \
    /usr/local/bin/benchmark-haskell-cassandra-api

EXPOSE 8080

ENTRYPOINT ["/usr/local/bin/benchmark-haskell-cassandra-api", "+RTS", "-N2", "-RTS"]
