FROM alpine:3.3

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
    nmap

RUN \
  rm -rf /var/cache/apk/*

ADD rootfs/ /

CMD [ '/bin/bash' ]
