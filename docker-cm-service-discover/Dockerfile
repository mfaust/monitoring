
FROM bodsch/docker-ruby

MAINTAINER Bodo Schulz <bodo.schulz@coremedia.com>

LABEL version="1.5.0"

EXPOSE 9001

ENV TERM=xterm

# ---------------------------------------------------------------------------------------

WORKDIR /srv
VOLUME  /srv

RUN \
  apk --quiet --no-cache update && \
  apk --quiet --no-cache upgrade && \
  apk --quiet --no-cache add \
    build-base \
    imagemagick-dev \
    ruby-dev \
    sqlite-dev \
    sqlite \
    yajl-tools \
    fping \
    zlib \
    zlib-dev && \
  gem install --no-rdoc --no-ri \
    bigdecimal \
    beaneater \
    ipaddress \
    resolve-hostname \
    rest-client \
    sqlite3 \
    sequel \
    time_difference \
    filesize \
    fileutils && \
  mkdir /var/log/monitoring && \
  mkdir /var/cache/monitoring && \
  apk del --purge \
    build-base \
    imagemagick-dev \
    ruby-dev \
    zlib-dev && \
  rm -rf /var/cache/apk/*

COPY rootfs/ /

# CMD /opt/startup.sh

CMD ["/bin/sh"]
