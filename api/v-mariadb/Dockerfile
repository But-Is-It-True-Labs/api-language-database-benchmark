FROM thevlang/vlang AS build

RUN apk add --no-cache \
    mariadb-connector-c-dev \
    musl-dev \
    gc-dev \
    build-base

WORKDIR /src

COPY main.v .

RUN v -d new_veb \
    -prod \
    -cc gcc \
    -o /out-benchmark-v-api \
    main.v


FROM alpine:3.18

RUN apk add --no-cache \
    mariadb-connector-c \
    gc \
    libgcc \
    libstdc++

COPY --from=build \
    /out-benchmark-v-api \
    /usr/local/bin/benchmark-v-api

EXPOSE 8080

ENTRYPOINT ["/usr/local/bin/benchmark-v-api"]
