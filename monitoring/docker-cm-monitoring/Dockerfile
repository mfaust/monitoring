
FROM docker-alpine-base:latest

MAINTAINER Bodo Schulz <bodo.schulz@coremedia.com>

LABEL version="0.10.0"

# ---------------------------------------------------------------------------------------

WORKDIR /app
VOLUME  /app

RUN \
  apk --quiet update

RUN \
  apk --quiet add \
    bash \
    nano \
    python \
    jq \
    bc \
    yajl-tools \
    collectd \
    fping \
    nmap

RUN \
  rm -rf /var/cache/apk/*

RUN \
  mv /etc/collectd/collectd.conf /etc/collectd/collectd.conf.dist

ADD rootfs/ /

ENTRYPOINT [ "/opt/startup.sh" ]
