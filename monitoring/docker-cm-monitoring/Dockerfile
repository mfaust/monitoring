
FROM alpine:edge

MAINTAINER Bodo Schulz <bodo@boone-schulz.de>

LABEL version="0.9.2"

# ---------------------------------------------------------------------------------------

WORKDIR /app
VOLUME  /app

RUN \
  echo "@testing http://nl.alpinelinux.org/alpine/edge/testing" >>  /etc/apk/repositories

RUN \
  apk --quiet update && \
  apk --quiet upgrade

RUN \
  apk --quiet add \
    bash \
    nano \
    python \
    curl \
    jq \
    bc \
    yajl-tools \
    collectd \
    fping \
    nmap \
    supervisor

RUN \
  rm -rf /var/cache/apk/*

RUN \
  mv /etc/collectd/collectd.conf /etc/collectd/collectd.conf.dist

ADD rootfs/ /

# CMD [ '/bin/bash' ]
ENTRYPOINT [ "/opt/startup.sh" ]
