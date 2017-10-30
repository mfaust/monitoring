
FROM alpine:3.6

MAINTAINER Bodo Schulz <bodo.schulz@coremedia.com>

ENV \
  ALPINE_MIRROR="mirror1.hs-esslingen.de/pub/Mirrors" \
  ALPINE_VERSION="v3.6" \
  TERM=xterm \
  BUILD_DATE="2017-10-26" \
  BUILD_TYPE="stable" \
  BEANSTALKD_VERSION="1.10" \
  APK_ADD="build-base git ruby ruby-dev nano" \
  APK_DEL="build-base git ruby-dev" \
  GEMS="aws-sdk beaneater ipaddress json rufus-scheduler tzinfo-data"

EXPOSE 11300

LABEL \
  version="1710"

# ---------------------------------------------------------------------------------------

RUN \
  echo "http://${ALPINE_MIRROR}/alpine/${ALPINE_VERSION}/main"       > /etc/apk/repositories && \
  echo "http://${ALPINE_MIRROR}/alpine/${ALPINE_VERSION}/community" >> /etc/apk/repositories && \
  apk --no-cache update && \
  apk --no-cache upgrade && \
  apk --no-cache add ${APK_ADD} && \

  #
  gem install --no-rdoc --no-ri ${GEMS}

#  apk del --purge ${APK_ADD} && \
#  rm -rf \
#    /opt/* \
#    /tmp/* \
#    /var/cache/apk/

COPY rootfs/ /

ENTRYPOINT [ "/init/run.sh" ]

CMD ["/bin/sh"]

# EOF

