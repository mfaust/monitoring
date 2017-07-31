
FROM alpine:3.6

MAINTAINER Bodo Schulz <bodo.schulz@coremedia.com>

ENV \
  VERSION="1707-31.1" \
  BUILD_DATE="2017-07-31" \
  ALPINE_MIRROR="mirror1.hs-esslingen.de/pub/Mirrors" \
  ALPINE_VERSION="v3.6" \
  TERM=xterm \
  APK_ADD="build-base bind-tools drill ruby ruby-dev nano" \
  APK_DEL="build-base ruby-dev" \
  GEMS="aws-sdk ipaddress json rest-client rufus-scheduler tzinfo-data"

# ---------------------------------------------------------------------------------------

WORKDIR /

RUN \
  echo "http://${ALPINE_MIRROR}/alpine/${ALPINE_VERSION}/main"       > /etc/apk/repositories && \
  echo "http://${ALPINE_MIRROR}/alpine/${ALPINE_VERSION}/community" >> /etc/apk/repositories && \
  apk --no-cache update && \
  apk --no-cache upgrade && \
  apk --no-cache add ${APK_ADD} && \
  gem install --no-rdoc --no-ri ${GEMS} && \
  apk --purge del ${APK_DEL} && \
  rm -rf \
    /tmp/* \
    /var/cache/apk/*

COPY rootfs/ /

CMD [ "/usr/local/bin/external-discover.rb" ]
