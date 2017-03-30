
FROM alpine:latest

MAINTAINER Bodo Schulz <bodo.schulz@coremedia.com>

ENV \
  ALPINE_MIRROR="dl-cdn.alpinelinux.org" \
  ALPINE_VERSION="v3.5" \
  TERM=xterm \
  APK_ADD="build-base openssl-dev ruby-dev ruby-irb ruby-rdoc zlib zlib-dev" \
  APK_DEL="build-base ruby-dev ruby-rdoc zlib-dev" \
  GEMS="beaneater dalli json openssl rest-client rufus-scheduler tzinfo-data"

LABEL version="1703-03.1"

# ---------------------------------------------------------------------------------------

WORKDIR /

RUN \
  echo "http://${ALPINE_MIRROR}/alpine/${ALPINE_VERSION}/main"       > /etc/apk/repositories && \
  echo "http://${ALPINE_MIRROR}/alpine/${ALPINE_VERSION}/community" >> /etc/apk/repositories && \
  apk --quiet --no-cache update && \
  apk --quiet --no-cache upgrade && \
  for apk in ${APK_ADD} ; \
  do \
    apk --quiet --no-cache add ${apk} ; \
  done && \
  for gem in ${GEMS} ; \
  do \
     gem install --quiet --no-rdoc --no-ri ${gem} ; \
  done && \
  for apk in ${APK_DEL} ; \
  do \
    apk del --quiet --purge ${apk} ; \
  done && \
  mkdir /var/cache/monitoring && \
  rm -rf \
    /tmp/* \
    /var/cache/apk/*

COPY rootfs/ /

CMD [ "/usr/local/bin/icinga-client.rb" ]