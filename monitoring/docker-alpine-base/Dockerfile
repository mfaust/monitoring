FROM alpine:edge

MAINTAINER Bodo Schulz <bodo.schulz@coremedia.com>

LABEL version="1.0.0"

# ---------------------------------------------------------------------------------------------------------------------

RUN \
  echo "http://fr.alpinelinux.org/alpine/edge/testing" >>  /etc/apk/repositories

RUN \
  apk --quiet update && \
  apk --quiet upgrade

RUN \
  rm -Rf /var/run && \
  ln -s /run /var/run

RUN \
  apk --quiet add \
    curl \
    ca-certificates \
    supervisor

RUN \
  mkdir /opt

RUN \
  rm -rf /tmp/* /var/cache/apk/*

CMD [ '/bin/sh' ]
