
FROM alpine:3.6

MAINTAINER Bodo Schulz <bodo.schulz@coremedia.com>

ENV \
  ALPINE_MIRROR="mirror1.hs-esslingen.de/pub/Mirrors" \
  ALPINE_VERSION="v3.6" \
  TERM=xterm \
  BUILD_DATE="2017-10-30" \
  APK_ADD="build-base git ruby ruby-dev nano" \
  APK_DEL="build-base git ruby-dev" \
  GEMS="io-console bundler"

EXPOSE 8080

LABEL \
  version="1710"

# ---------------------------------------------------------------------------------------

COPY build /build

RUN \
  echo "http://${ALPINE_MIRROR}/alpine/${ALPINE_VERSION}/main"       > /etc/apk/repositories && \
  echo "http://${ALPINE_MIRROR}/alpine/${ALPINE_VERSION}/community" >> /etc/apk/repositories && \
  apk --no-cache update && \
  apk --no-cache upgrade && \
  apk --no-cache add ${APK_ADD} && \
  #
  gem install --quiet --no-rdoc --no-ri ${GEMS} && \
  #
#   count=$(ls -1 /build/*.gem 2> /dev/null | tail -n1) && \
#   if [ ! -z ${count} ] ; then \
#     gem install --quiet --no-rdoc --no-ri ${count} ; \
#   else \
#     echo "gem 'icinga2', '~> ${ICINGA2_GEM_VERSION}'" >> /build/Gemfile ; \
#   fi && \
  #
  cd /build && \
  bundle install --quiet



  #
#  apk --quiet --purge del ${APK_DEL} && \
#  rm -rf \
#    /opt/* \
#    /tmp/* \
#    /root/.bundle \
#    /root/.gem \
#    /var/cache/apk/*

COPY rootfs/ /

ENTRYPOINT [ "/init/run.sh" ]

CMD ["/bin/sh"]

# EOF
