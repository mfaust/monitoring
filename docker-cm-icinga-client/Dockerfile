
FROM alpine:3.6

MAINTAINER Bodo Schulz <bodo.schulz@coremedia.com>

ENV \
  ALPINE_MIRROR="mirror1.hs-esslingen.de/pub/Mirrors" \
  ALPINE_VERSION="v3.6" \
  TERM=xterm \
  APK_ADD="build-base bind-tools drill git mariadb-dev libressl-dev ruby-dev ruby-irb ruby-rdoc" \
  APK_DEL="build-base git ruby-dev ruby-rdoc " \
  GEMS="beaneater ipaddress icinga2 json mysql2 rufus-scheduler tzinfo-data"

LABEL version="1707-28.1"

# ---------------------------------------------------------------------------------------

WORKDIR /

RUN \
  echo "http://${ALPINE_MIRROR}/alpine/${ALPINE_VERSION}/main"       > /etc/apk/repositories && \
  echo "http://${ALPINE_MIRROR}/alpine/${ALPINE_VERSION}/community" >> /etc/apk/repositories && \
  apk --no-cache update && \
  apk --no-cache upgrade && \
  apk --no-cache add ${APK_ADD} && \
  gem install --quiet --no-rdoc --no-ri ${GEMS} && \
  apk --purge del ${APK_DEL} && \
  mkdir /var/cache/monitoring && \
  rm -rf \
    /opt/* \
    /tmp/* \
    /var/cache/apk/*

COPY rootfs/ /

CMD [ "/usr/local/bin/icinga-client.rb" ]
