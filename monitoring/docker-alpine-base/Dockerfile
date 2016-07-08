FROM alpine:edge

MAINTAINER Bodo Schulz <bodo.schulz@coremedia.com>

LABEL version="1.1.0"

# ---------------------------------------------------------------------------------------------------------------------

RUN \
  echo "http://nl.alpinelinux.org/alpine/edge/testing" >>  /etc/apk/repositories && \
  apk --quiet --no-cache update && \
  apk --quiet --no-cache upgrade && \
  apk --quiet --no-cache add \
    curl \
    ca-certificates \
    supervisor && \
  mkdir /opt && \
  rm -Rf /var/run && \
  ln -s /run /var/run && \
  rm -rf /tmp/* && \
  rm -rf /var/tmp && \
  rm -rf /var/cache/apk/*

CMD [ '/bin/sh' ]
