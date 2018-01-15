
FROM bodsch/docker-icinga2:2.8.0-r4

MAINTAINER Bodo Schulz <bodo.schulz@coremedia.com>

ENV \
  VERSION="1801" \
  BUILD_DATE="2018-01-15" \
  TERM=xterm \
  TZ='Europe/Berlin'

# ---------------------------------------------------------------------------------------

RUN \
  apk --quiet --no-cache update && \
  apk --quiet --no-cache upgrade && \
  apk add --quiet --no-cache --virtual .build-deps tzdata && \
  cp /usr/share/zoneinfo/$TZ /etc/localtime && \
  echo $TZ > /etc/timezone && \
  apk del --quiet .build-deps

COPY rootfs/ /
COPY build /build

RUN \
  apk add --quiet --no-cache --virtual .build-deps \
    g++ make ruby-dev && \
  gem install --quiet --no-rdoc --no-ri \
    io-console bundler && \
  cd /build && \
  bundle install --quiet && \
  for g in $(ls -1 /build/*.gem 2> /dev/null) ; do echo $g; gem install --quiet --no-rdoc --no-ri ${g} ; done && \
  gem uninstall --quiet \
    io-console bundler && \
  apk del --quiet .build-deps && \
  rm -rf \
    /tmp/* \
    /build  \
    /root/.bundle \
    /root/.gem \
    /var/cache/apk/*

HEALTHCHECK \
  --interval=5s \
  --timeout=2s \
  --retries=12 \
  CMD curl --silent --fail localhost:8080/v2/health-check || exit 1
