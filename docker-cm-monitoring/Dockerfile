
FROM bodsch/docker-alpine-base:alpine-3.5

MAINTAINER Bodo Schulz <bodo.schulz@coremedia.com>

LABEL version="1.4.0"

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
    drill \
    ruby-dev \
    ruby-irb \
    ruby-io-console \
    ruby-rdoc \
    python \
    jq \
    bc \
    yajl-tools \
    collectd \
    collectd-log_logstash \
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
     ruby-supervisor \
     sinatra \
     thin \
     dalli && \
  mv /etc/collectd/collectd.conf /etc/collectd/collectd.conf.dist && \
  apk del --purge \
    build-base \
    imagemagick-dev \
    mysql-dev \
    ruby-dev \
    zlib-dev && \
  rm -rf /var/cache/apk/*

COPY rootfs/ /


CMD /opt/startup.sh
