FROM ruby:3.4-slim

RUN apt-get update \
    && apt-get install -y \
       build-essential \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY Gemfile .

RUN bundle install

COPY app.rb .
COPY config.ru .
COPY puma.rb .

EXPOSE 8080

ENTRYPOINT ["bundle", "exec", "puma", "-C", "puma.rb"]
