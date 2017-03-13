
FROM bodsch/docker-ruby

MAINTAINER Bodo Schulz <bodo.schulz@coremedia.com>

LABEL version="1.2.0"

# ---------------------------------------------------------------------------------------

RUN \
  apk --quiet --no-cache update && \
  apk --quiet --no-cache upgrade && \
  apk --quiet --no-cache add \
    build-base \
    bind-tools \
    imagemagick-dev \
    ruby-dev \
    sqlite-dev \
    sqlite \
    mysql-dev \
    postgresql-dev && \
  gem install --no-rdoc --no-ri \
    bigdecimal \
    beaneater \
    rufus-scheduler \
    ipaddress \
    resolve-hostname \
    time_difference \
    tzinfo-data \
    sqlite3 \
    sequel \
    rest-client \
    mysql2 \
    pg && \
  mkdir /var/log/monitoring && \
  mkdir /var/cache/monitoring && \
  apk del --purge \
    build-base \
    imagemagick-dev \
    ruby-dev \
    zlib-dev \
    supervisor \
    bash \
    nano \
    curl \
    ca-certificates \
    ruby-io-console \
    tree && \
  rm -rf /var/cache/apk/*

COPY rootfs/ /

# ENTRYPOINT /usr/local/bin/external-discover.rb

CMD ["/usr/local/bin/data-collector.rb"]
