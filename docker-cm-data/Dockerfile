
FROM alpine:latest

MAINTAINER Bodo Schulz <bodo.schulz@coremedia.com>

ENV \
  ALPINE_MIRROR="dl-cdn.alpinelinux.org" \
  ALPINE_VERSION="v3.5"

LABEL version="1704-01.1"

# ---------------------------------------------------------------------------------------

WORKDIR /

# VOLUME [ "/share" ]

ADD rootfs /

RUN \
  mkdir -p /share && \
  rm -rf \
    /tmp/* \
    /var/cache/apk/*

ENTRYPOINT ["/entrypoint.sh"]

CMD ["tail", "-f", "/dev/null"]