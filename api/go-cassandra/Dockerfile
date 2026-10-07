FROM golang:1.25-alpine AS build

WORKDIR /src

COPY go.mod go.sum ./
RUN go mod download

COPY main.go .

RUN CGO_ENABLED=0 GOOS=linux go build \
    -trimpath \
    -ldflags="-s -w" \
    -o /benchmark-go-cassandra \
    main.go

FROM alpine:3.22

RUN apk add --no-cache ca-certificates

COPY --from=build /benchmark-go-cassandra /usr/local/bin/benchmark-go-cassandra

EXPOSE 8080

ENTRYPOINT ["/usr/local/bin/benchmark-go-cassandra"]
