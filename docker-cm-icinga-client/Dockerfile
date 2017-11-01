
FROM alpine:3.6

MAINTAINER Bodo Schulz <bodo.schulz@coremedia.com>

ENV \
  VERSION="1710.1" \
  BUILD_DATE="2017-10-27" \
  ALPINE_MIRROR="mirror1.hs-esslingen.de/pub/Mirrors" \
  ALPINE_VERSION="v3.6" \
  TERM=xterm \
  APK_ADD="build-base bind-tools drill git mariadb-dev libressl-dev ruby-dev ruby-irb ruby-rdoc" \
  APK_DEL="build-base git ruby-dev ruby-rdoc " \
  GEMS="io-console bundler" \
  ICINGA2_GEM_VERSION="1.0"

# ---------------------------------------------------------------------------------------

WORKDIR /

COPY build /build

RUN \
  echo "http://${ALPINE_MIRROR}/alpine/${ALPINE_VERSION}/main"       > /etc/apk/repositories && \
  echo "http://${ALPINE_MIRROR}/alpine/${ALPINE_VERSION}/community" >> /etc/apk/repositories && \
  apk --quiet --no-cache update && \
  apk --quiet --no-cache upgrade && \
  apk --quiet --no-cache add ${APK_ADD} && \
  #
  gem install --quiet --no-rdoc --no-ri ${GEMS} && \
  #
  count=$(ls -1 /build/*.gem 2> /dev/null | tail -n1) && \
  if [ ! -z ${count} ] ; then \
    gem install --quiet --no-rdoc --no-ri ${count} ; \
  else \
    echo "gem 'icinga2', '~> ${ICINGA2_GEM_VERSION}'" >> /build/Gemfile ; \
  fi && \
  #
  cd /build && \
  bundle install --quiet && \
  #
  apk --quiet --purge del ${APK_DEL} && \
  rm -rf \
    /opt/* \
    /tmp/* \
    /root/.bundle \
    /root/.gem \
    /var/cache/apk/*

COPY rootfs/ /

CMD [ "/usr/local/bin/icinga-client.rb" ]
