
FROM bodsch/docker-alpine-base:1612-01

MAINTAINER Bodo Schulz <bodo.schulz@coremedia.com>

LABEL version="1.4.1"

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
    sqlite-dev \
    drill \
    ruby-dev \
    ruby-irb \
    ruby-io-console \
    ruby-rdoc \
    python \
    sqlite \
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
    zlib-dev

#RUN \
#  for p in erb gem irb rdoc ri ruby testrb ; do  ln -s /usr/bin/${p}2.2 /usr/bin/${p} ; done

RUN \
   gem install --no-rdoc --no-ri \
     bigdecimal \
     ipaddress \
     resolve-hostname \
     rest-client \
     mysql2 \
     sqlite3 \
     sequel \
     time_difference \
     filesize \
     fileutils \
     ruby-supervisor \
     sinatra \
     thin \
     dalli

# RUN \
#    mv /etc/collectd/collectd.conf /etc/collectd/collectd.conf.dist && \
#    apk del --purge \
#      build-base \
#      imagemagick-dev \
#      mysql-dev \
#      sqlite-dev \
#      ruby-dev \
#      zlib-dev && \
#    rm -rf /var/cache/apk/*
#
COPY rootfs/ /


CMD /opt/startup.sh

# CMD /bin/bash
