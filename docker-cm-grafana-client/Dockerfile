
FROM alpine:3.6

MAINTAINER Bodo Schulz <bodo.schulz@coremedia.com>

ENV \
  VERSION="1707-31.1" \
  BUILD_DATE="2017-07-31" \
  ALPINE_MIRROR="mirror1.hs-esslingen.de/pub/Mirrors" \
  ALPINE_VERSION="v3.6" \
  TERM=xterm \
  APK_ADD="build-base bind-tools drill imagemagick-dev mariadb-client mariadb-dev ruby-dev ruby-irb" \
  APK_DEL="build-base imagemagick-dev ruby-dev" \
  GEMS="beaneater bigdecimal ipaddress json mysql2 redis resolve-hostname rest-client rufus-scheduler tzinfo-data"

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

CMD [ "/usr/local/bin/grafana-client.rb" ]
