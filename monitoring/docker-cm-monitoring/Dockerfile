FROM bodsch/docker-alpine-base:3.4

MAINTAINER Bodo Schulz <bodo.schulz@coremedia.com>

LABEL version="1.2.4"

ENV TERM=xterm

# ---------------------------------------------------------------------------------------

WORKDIR /srv
VOLUME  /srv

RUN \
  apk --quiet --no-cache update && \
  apk --quiet --no-cache upgrade && \
  apk --quiet  --no-cache add \
    build-base \
    imagemagick-dev \
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
     sequel \
     time_difference \
     filesize \
     fileutils \
     sinatra \
     thin

RUN \
  rm -rf /var/cache/apk/*

RUN \
  mv /etc/collectd/collectd.conf /etc/collectd/collectd.conf.dist

ADD rootfs/ /

# CMD [ '/bin/bash' ]

ENTRYPOINT [ "/opt/startup.sh" ]
