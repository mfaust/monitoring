
FROM alpine:latest as builder

RUN \
  apk --no-cache update && \
  apk --no-cache upgrade

RUN \
  apk add --quiet --no-cache \
    bash \
    build-base \
    bison \
    cmake \
    curl \
    flex \
    git \
    hiredis-dev libev-dev

RUN \
  cd /tmp/ && \
  git clone https://github.com/bodsch/coremedia_icinga2_checks.git && \
  git clone https://github.com/hmartiro/redox.git && \
  git clone https://github.com/nlohmann/json

RUN \
  cd /tmp/redox && \
  cmake -H. -Bbuild && \
  cmake --build build -- -j3 && \
  cd build && \
  make install

RUN \
  cd /tmp/json && \
  cp -ar /tmp/json/include/nlohmann /usr/local/include/ && \
  ls -1 /usr/local/include/

RUN \
  cd /tmp/coremedia_icinga2_checks && \
  cmake -H. -Bbuild && \
  cmake --build build -- -j3

# ---------------------------------------------------------------------------------------

FROM bodsch/docker-icinga2:2.8.2-master-r2

MAINTAINER Bodo Schulz <bodo.schulz@coremedia.com>

ENV \
  VERSION="1803" \
  BUILD_DATE="2018-03-21" \
  TERM=xterm \
  TZ='Europe/Berlin'

# ---------------------------------------------------------------------------------------

COPY build /build

RUN \
  apk --quiet --no-cache update && \
  apk add --quiet --no-cache --virtual .build-deps \
    g++ make ruby-dev tzdata && \
  apk add --quiet --no-cache \
    libev hiredis && \
  gem install --quiet --no-rdoc --no-ri \
    io-console bundler && \
  cp /usr/share/zoneinfo/${TZ} /etc/localtime && \
  echo ${TZ} > /etc/timezone && \
  cd /build && \
  bundle install --quiet && \
  for g in $(ls -1 /build/*.gem 2> /dev/null) ; \
  do \
    echo $g; \
    gem install --quiet --no-rdoc --no-ri ${g} ; \
  done && \
  gem uninstall --quiet \
    io-console bundler && \
  apk del --quiet .build-deps && \
  rm -rf \
    /tmp/* \
    /build  \
    /root/.bundle \
    /root/.gem \
    /var/cache/apk/*

COPY --from=builder /tmp/coremedia_icinga2_checks/build/check_*  /usr/lib/monitoring-plugins/
COPY --from=builder /usr/local/lib64 /usr/local/lib64
COPY rootfs/ /
