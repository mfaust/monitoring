
FROM bodsch/docker-alpine-base:1610-02

MAINTAINER Bodo Schulz <bodo.schulz@coremedia.com>

LABEL version="1.3.3"

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
    mysql-dev \
    bash \
    ruby-dev \
    ruby-irb \
    ruby-io-console \
    ruby-rdoc \
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
    nrpe-plugin \
    bind-tools \
    zlib \
    zlib-dev && \
   gem install --no-rdoc --no-ri \
     bigdecimal \
     json \
     ipaddress \
     resolve-hostname \
     rest-client \
     mysql2 \
     time_difference \
     filesize \
     fileutils \
     sinatra \
     thin \
     dalli

RUN \
  rm -rf /var/cache/apk/*

RUN \
  mv /etc/collectd/collectd.conf /etc/collectd/collectd.conf.dist

COPY rootfs/ /


CMD /opt/startup.sh
