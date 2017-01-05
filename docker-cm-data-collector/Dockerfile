
FROM bodsch/docker-ruby

MAINTAINER Bodo Schulz <bodo.schulz@coremedia.com>

ENV TERM=xterm

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
    mysql-dev && \
  gem install --no-rdoc --no-ri \
    bigdecimal \
    ipaddress \
    resolve-hostname \
    rest-client \
    mysql2 && \
  mkdir /var/log/monitoring && \
  mkdir /var/cache/monitoring && \
  apk del --purge \
    build-base \
    imagemagick-dev \
    ruby-dev \
    zlib-dev
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

CMD /bin/sh
