
FROM bodsch/docker-ruby

MAINTAINER Bodo Schulz <bodo.schulz@coremedia.com>

LABEL version="1.5.0"

EXPOSE 9001

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
    sqlite && \
  gem install --no-rdoc --no-ri \
    beaneater \
    ipaddress \
    resolve-hostname \
    sqlite3 \
    sequel \
    filesize && \
  mkdir /var/log/monitoring && \
  mkdir /var/cache/monitoring && \
  apk del --purge \
    build-base \
    imagemagick-dev \
    ruby-dev \
    zlib-dev && \
  rm -rf /var/cache/apk/*

COPY rootfs/ /

CMD ["/usr/local/bin/service-discovery.rb"]
