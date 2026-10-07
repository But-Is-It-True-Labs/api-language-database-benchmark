FROM php:8.4-fpm-trixie

RUN apt-get update \
    && apt-get install -y \
        nginx \
        git \
        ca-certificates \
        build-essential \
        cmake \
        ninja-build \
        pkg-config \
        libuv1-dev \
        libssl-dev \
        libgmp-dev \
        zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*


# Apache Cassandra C/C++ driver 2.17.1
RUN git clone \
        --depth 1 \
        --branch 2.17.1 \
        https://github.com/apache/cassandra-cpp-driver.git \
        /tmp/cassandra-cpp-driver \
    && cmake \
        -S /tmp/cassandra-cpp-driver \
        -B /tmp/cassandra-cpp-driver/build \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_CXX_STANDARD=11 \
        -DCASS_BUILD_SHARED=ON \
        -DCASS_BUILD_STATIC=OFF \
        -DCASS_BUILD_EXAMPLES=OFF \
        -DCASS_BUILD_TESTS=OFF \
        -DCASS_USE_LIBSSH2=OFF \
        -DCASS_USE_ZLIB=ON \
        -DCMAKE_INSTALL_PREFIX=/usr/local/cassandra \
    && cmake \
        --build /tmp/cassandra-cpp-driver/build \
        --parallel \
    && cmake \
        --install /tmp/cassandra-cpp-driver/build \
    && printf \
        "/usr/local/cassandra/lib\n/usr/local/cassandra/lib64\n" \
        > /etc/ld.so.conf.d/cassandra.conf \
    && ldconfig


# Modern PHP Cassandra/ScyllaDB extension
RUN git clone \
        --depth 1 \
        --branch v1.5.1 \
        --recursive \
        https://github.com/he4rt/scylladb-php-driver.git \
        /tmp/php-cassandra-driver \
    && cmake \
        -S /tmp/php-cassandra-driver \
        -B /tmp/php-cassandra-driver/build \
        -G Ninja \
        -DCMAKE_BUILD_TYPE=Release \
        -DCUSTOM_PHP_CONFIG=/usr/local/bin/php-config \
        -DPHP_DEBUG=OFF \
        -DPHP_THREAD_SAFE=OFF \
        -DUSE_LIBCASSANDRA=ON \
        -DCPP_DRIVER_PREFIX=/usr/local/cassandra \
    && cmake \
        --build /tmp/php-cassandra-driver/build \
        --parallel \
    && CASS_SO="$(find /tmp/php-cassandra-driver/build \
        -type f \
        -name cassandra.so \
        | head -1)" \
    && test -n "$CASS_SO" \
    && cp "$CASS_SO" \
        "$(php-config --extension-dir)/cassandra.so" \
    && echo "extension=cassandra.so" \
        > /usr/local/etc/php/conf.d/20-cassandra.ini \
    && php -m | grep -i '^cassandra$'


WORKDIR /app

COPY index.php /app/index.php

COPY nginx.conf \
    /etc/nginx/conf.d/default.conf

COPY www.conf \
    /usr/local/etc/php-fpm.d/www.conf

COPY start.sh \
    /usr/local/bin/start-benchmark

RUN chmod +x \
    /usr/local/bin/start-benchmark

EXPOSE 8080

ENTRYPOINT ["/usr/local/bin/start-benchmark"]
