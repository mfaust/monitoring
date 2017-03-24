
FROM alpine:latest

MAINTAINER Bodo Schulz <bodo.schulz@coremedia.com>

ENV \
  ALPINE_MIRROR="dl-cdn.alpinelinux.org" \
  ALPINE_VERSION="v3.5" \
  TERM=xterm \
  GEMS="beaneater bigdecimal dalli filesize fileutils ipaddress mysql2 resolve-hostname rest-client sequel sinatra sqlite3 thin"

LABEL version="1703-03.1"

# ---------------------------------------------------------------------------------------

WORKDIR /srv
VOLUME  /srv

RUN \
  echo "http://${ALPINE_MIRROR}/alpine/${ALPINE_VERSION}/main"       > /etc/apk/repositories && \
  echo "http://${ALPINE_MIRROR}/alpine/${ALPINE_VERSION}/community" >> /etc/apk/repositories && \
  apk --quiet --no-cache update && \
  apk --quiet --no-cache upgrade && \
  apk --quiet --no-cache add \
    build-base \
    bind-tools \
    drill \
    imagemagick-dev \
    mysql-dev \
    ruby-dev \
    ruby-irb \
    ruby-io-console \
    ruby-rdoc \
    sqlite \
    sqlite-dev \
    zlib \
    zlib-dev && \
  for gem in ${GEMS} ; \
  do \
     gem install --quiet --no-rdoc --no-ri ${gem} ; \
  done && \
  mkdir /var/cache/monitoring && \
  apk del --purge \
    build-base \
    imagemagick-dev \
    ruby-dev \
    zlib-dev && \
  rm -rf \
    /tmp/* \
    /var/cache/apk/*

COPY rootfs/ /

CMD [ "/opt/startup.sh" ]
