
FROM bodsch/docker-icinga2:2.8.0-r4

MAINTAINER Bodo Schulz <bodo.schulz@coremedia.com>

ENV \
  VERSION="1801" \
  BUILD_DATE="2018-01-15" \
  TERM=xterm \
  TZ='Europe/Berlin'

# ---------------------------------------------------------------------------------------

COPY rootfs/ /
COPY build /build

RUN \
  apk --quiet --no-cache update && \
  apk add --quiet --no-cache --virtual .build-deps \
    g++ make ruby-dev tzdata && \
  gem install --quiet --no-rdoc --no-ri \
    io-console bundler && \
  cp /usr/share/zoneinfo/$TZ /etc/localtime && \
  echo $TZ > /etc/timezone && \
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
