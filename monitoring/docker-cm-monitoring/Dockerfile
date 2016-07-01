
FROM docker-alpine-base:latest

MAINTAINER Bodo Schulz <bodo.schulz@coremedia.com>

LABEL version="1.2.1"

# ---------------------------------------------------------------------------------------

WORKDIR /app
VOLUME  /app

RUN \
  apk --quiet update && \
  apk --quiet upgrade

RUN \
  apk --quiet add \
    build-base \
    bash \
    ruby-dev \
    ruby-irb \
    ruby-io-console \
    ruby-rdoc \
    sqlite \
    sqlite-dev \
    nano \
    python \
    jq \
    jo \
    bc \
    yajl-tools \
    collectd \
    fping \
    nmap \
    monitoring-plugins \
    bind-tools \
    zlib \
    zlib-dev

RUN \
  gem install \
    sqlite3 \
    ruby-nmap \
    jolokia

RUN \
  rm -rf /var/cache/apk/*

RUN \
  mv /etc/collectd/collectd.conf /etc/collectd/collectd.conf.dist

ADD rootfs/ /

ENTRYPOINT [ "/opt/startup.sh" ]
