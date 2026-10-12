FROM elixir:1.18-alpine AS build

RUN apk add --no-cache \
    build-base \
    git

WORKDIR /app

ENV MIX_ENV=prod

RUN mix local.hex --force \
    && mix local.rebar --force

COPY mix.exs .

RUN mix deps.get \
    && mix deps.compile

COPY config ./config
COPY lib ./lib

RUN mix compile


FROM elixir:1.18-alpine

WORKDIR /app

ENV MIX_ENV=prod

RUN mix local.hex --force \
    && mix local.rebar --force

COPY --from=build /app /app

EXPOSE 8080

ENTRYPOINT ["mix", "run", "--no-halt"]
