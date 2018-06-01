
FROM bitnami/minideb:latest as builder

ENV \
  TERM=xterm \
  DEBIAN_FRONTEND=noninteractive

RUN \
  DIST=$(awk -F"[)(]+" '/VERSION=/ {print $2}' /etc/os-release) && \
  chsh -s /bin/bash && \
  ln -sf /bin/bash /bin/sh && \
  ln -s  /sbin/killall5 /sbin/killall && \
  apt-get update  --quiet --quiet > /dev/null && \
  apt-get dist-upgrade --quiet --quiet > /dev/null && \
  apt-get install --quiet --quiet --assume-yes --no-install-recommends \
    bash \
    bzip2 \
    curl \
    ca-certificates \
    cmake \
    file \
    git \
    g++ \
    gnupg2 \
    make \
    libhiredis-dev \
    libev-dev \
    > /dev/null

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

FROM bodsch/docker-icinga2:2.8.4-master

MAINTAINER Bodo Schulz <bodo.schulz@coremedia.com>

ENV \
  VERSION="1806" \
  BUILD_DATE="2018-06-01" \
  TERM=xterm \
  DEBIAN_FRONTEND=noninteractive \
  TZ='Europe/Berlin'

# ---------------------------------------------------------------------------------------

COPY build /build

RUN \
  apt-get update --quiet --quiet > /dev/null && \
  apt-get install --quiet --quiet --assume-yes --no-install-recommends \
    g++ make ruby-dev && \
  echo 'gem: --no-document' >> /etc/gemrc && \
  gem install --quiet --no-rdoc --no-ri \
    io-console bundler && \
  apt-get install --quiet --quiet --assume-yes --no-install-recommends \
    libhiredis0.13 libev4 && \
  /usr/sbin/icinga2 feature enable command checker mainlog notification && \
  cd /build && \
  bundle install --quiet && \
  for g in $(ls -1 /build/*.gem 2> /dev/null) ; \
  do \
    echo $g; \
    gem install --quiet --no-rdoc --no-ri ${g} ; \
  done && \
  gem uninstall --quiet \
    io-console bundler && \
  apt-get clean --quiet --quiet > /dev/null && \
  rm -rf \
    /tmp/* \
    /var/cache/debconf/* \
    /usr/share/doc/* \
    /root/.gem \
    /root/.bundle

COPY --from=builder /tmp/coremedia_icinga2_checks/build/check_*  /usr/lib/monitoring-plugins/
COPY --from=builder /usr/local/lib64 /usr/local/lib64
COPY rootfs/ /
