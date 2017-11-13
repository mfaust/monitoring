
FROM alpine:3.6

MAINTAINER Bodo Schulz <bodo.schulz@coremedia.com>

ENV \
  VERSION="1711.1" \
  BUILD_DATE="2017-11-06" \
  ALPINE_MIRROR="mirror1.hs-esslingen.de/pub/Mirrors" \
  ALPINE_VERSION="v3.6" \
  TERM=xterm \
  GEMS="beaneater json rest-client rufus-scheduler semantic_logger tzinfo-data"

# ---------------------------------------------------------------------------------------

RUN \
  echo "http://${ALPINE_MIRROR}/alpine/${ALPINE_VERSION}/main"       > /etc/apk/repositories && \
  echo "http://${ALPINE_MIRROR}/alpine/${ALPINE_VERSION}/community" >> /etc/apk/repositories && \
  apk --no-cache update && \
  apk --no-cache upgrade && \
  apk add --quiet --no-cache --virtual .build-deps \
    build-base ruby-dev && \
  apk --quiet --no-cache add \
    ruby &&\
  echo 'gem: --no-document' >> /etc/gemrc && \
  gem install --no-rdoc --no-ri ${GEMS} && \
  apk del --quiet .build-deps && \
  rm -rf \
    /tmp/* \
    /var/cache/apk/*

COPY rootfs/ /

WORKDIR /

HEALTHCHECK \
  --interval=5s \
  --timeout=2s \
  --retries=12 \
  CMD ps ax | grep -c graphite-client.rb || exit 1

CMD [ "/usr/local/bin/graphite-client.rb" ]
