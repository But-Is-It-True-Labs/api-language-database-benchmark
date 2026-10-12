FROM golang:1.25 AS build

WORKDIR /src

COPY go.mod .
COPY main.go .

RUN go mod tidy

RUN CGO_ENABLED=0 GOOS=linux \
    go build \
    -trimpath \
    -ldflags="-s -w" \
    -o /benchmark-api .

FROM alpine:3.22

RUN adduser -D -H benchmark

COPY --from=build /benchmark-api /usr/local/bin/benchmark-api

USER benchmark

EXPOSE 8080

ENTRYPOINT ["/usr/local/bin/benchmark-api"]
