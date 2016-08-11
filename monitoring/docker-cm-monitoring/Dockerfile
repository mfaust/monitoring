FROM bodsch/docker-alpine-base:3.4

MAINTAINER Bodo Schulz <bodo.schulz@coremedia.com>

LABEL version="1.2.4"

# ---------------------------------------------------------------------------------------

WORKDIR /srv
VOLUME  /srv

RUN \
  apk --quiet update && \
  apk --quiet upgrade

RUN \
  apk --quiet add \
    build-base \
    imagemagick-dev \
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
    nrpe-plugin \
    bind-tools \
    zlib \
    zlib-dev

 RUN \
   gem install --no-rdoc --no-ri \
     sqlite3 \
     ruby-nmap \
     json \
     rest-client \
     filesize \
     fileutils \
     sinatra \
     thin

RUN \
  rm -rf /var/cache/apk/*

RUN \
  mv /etc/collectd/collectd.conf /etc/collectd/collectd.conf.dist

ADD rootfs/ /

CMD [ '/bin/bash' ]

# ENTRYPOINT [ "/opt/startup.sh" ]
