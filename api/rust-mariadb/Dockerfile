FROM rust:1-bookworm AS build

WORKDIR /src

COPY Cargo.toml .
COPY src ./src

RUN cargo build --release

FROM debian:bookworm-slim

RUN useradd \
    --system \
    --no-create-home \
    benchmark

COPY --from=build \
    /src/target/release/benchmark-rust-api \
    /usr/local/bin/benchmark-rust-api

USER benchmark

EXPOSE 8080

ENTRYPOINT ["/usr/local/bin/benchmark-rust-api"]
