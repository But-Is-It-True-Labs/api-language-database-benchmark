FROM php:8.4-fpm-bookworm

RUN apt-get update \
    && apt-get install -y \
        nginx \
    && docker-php-ext-install pdo_mysql \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY index.php /app/index.php

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY www.conf /usr/local/etc/php-fpm.d/www.conf
COPY start.sh /usr/local/bin/start-benchmark

RUN chmod +x /usr/local/bin/start-benchmark

EXPOSE 8080

ENTRYPOINT ["/usr/local/bin/start-benchmark"]
