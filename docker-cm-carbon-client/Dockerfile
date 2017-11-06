
FROM alpine:3.6

MAINTAINER Bodo Schulz <bodo.schulz@coremedia.com>

ENV \
  VERSION="1711.1" \
  BUILD_DATE="2017-11-06" \
  ALPINE_MIRROR="mirror1.hs-esslingen.de/pub/Mirrors" \
  ALPINE_VERSION="v3.6" \
  TERM=xterm \
  APK_ADD="build-base bind-tools imagemagick-dev mariadb-dev ruby-dev ruby-irb ruby-rdoc zlib zlib-dev" \
  APK_DEL="build-base imagemagick-dev ruby-dev ruby-rdoc zlib-dev" \
  GEMS="beaneater bigdecimal filesize json mini_cache mysql2 redis rest-client rufus-scheduler tzinfo-data"

# ---------------------------------------------------------------------------------------

RUN \
  echo "http://${ALPINE_MIRROR}/alpine/${ALPINE_VERSION}/main"       > /etc/apk/repositories && \
  echo "http://${ALPINE_MIRROR}/alpine/${ALPINE_VERSION}/community" >> /etc/apk/repositories && \
  apk --quiet --no-cache update && \
  apk --quiet --no-cache upgrade && \
  apk --quiet --no-cache add ${APK_ADD} && \
  gem install --quiet --no-rdoc --no-ri ${GEMS} && \
  apk --quiet --purge del ${APK_DEL} && \
  rm -rf \
    /tmp/* \
    /var/cache/apk/*

COPY rootfs/ /

CMD [ "/usr/local/bin/carbon-data.rb" ]
