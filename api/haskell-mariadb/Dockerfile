FROM haskell:9.10.3-bookworm AS build

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       default-libmysqlclient-dev \
       gcc \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src

COPY benchmark-haskell-api.cabal .

RUN cabal update \
    && cabal build --only-dependencies -j2

COPY Main.hs .

RUN cabal build -j2 \
    && mkdir -p /out \
    && cp "$(cabal list-bin exe:benchmark-haskell-api)" \
          /out/benchmark-haskell-api


FROM debian:bookworm-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       libmariadb3 \
       ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY --from=build \
    /out/benchmark-haskell-api \
    /usr/local/bin/benchmark-haskell-api

EXPOSE 8080

ENTRYPOINT ["/usr/local/bin/benchmark-haskell-api", "+RTS", "-N2", "-RTS"]
