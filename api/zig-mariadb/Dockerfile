FROM kassany/alpine-ziglang:0.16.0 AS build

USER root

RUN apk add --no-cache \
    build-base \
    musl-dev \
    mariadb-connector-c-dev

WORKDIR /src

COPY build.zig .
COPY build.zig.zon .
COPY src ./src

RUN zig build --fetch

RUN zig build \
    -Doptimize=ReleaseFast


FROM alpine:3.20

RUN apk add --no-cache \
    libgcc \
    libstdc++ \
    mariadb-connector-c

COPY --from=build \
    /src/zig-out/bin/benchmark-zig-api \
    /usr/local/bin/benchmark-zig-api

EXPOSE 8080

ENTRYPOINT ["/usr/local/bin/benchmark-zig-api"]
