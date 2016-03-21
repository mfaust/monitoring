
FROM alpine:edge

MAINTAINER Bodo Schulz <bodo@boone-schulz.de>

LABEL version="0.9.2"

# ---------------------------------------------------------------------------------------

WORKDIR /app
VOLUME  /app

RUN \
  apk --quiet update && \
  apk --quiet upgrade

RUN \
  apk --quiet add \
    bash \
    python \
    curl \
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

CMD [ '/bin/bash' ]
