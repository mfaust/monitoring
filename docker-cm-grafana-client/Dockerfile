
FROM alpine:3.6

MAINTAINER Bodo Schulz <bodo.schulz@coremedia.com>

ENV \
  VERSION="1710" \
  BUILD_DATE="2017-10-15" \
  ALPINE_MIRROR="mirror1.hs-esslingen.de/pub/Mirrors" \
  ALPINE_VERSION="v3.6" \
  TERM=xterm \
  GRAFANA_GEM_VERSION="0.5" \
  APK_ADD="build-base bind-tools drill imagemagick-dev mariadb-client mariadb-dev ruby-dev ruby-irb" \
  APK_DEL="build-base imagemagick-dev ruby-dev" \
  GEMS="io-console bundler"

#  beaneater bigdecimal ipaddress json mysql2 redis resolve-hostname rest-client rufus-scheduler tzinfo-data"

# ---------------------------------------------------------------------------------------

COPY build /build

WORKDIR /

RUN \
  echo "http://${ALPINE_MIRROR}/alpine/${ALPINE_VERSION}/main"       > /etc/apk/repositories && \
  echo "http://${ALPINE_MIRROR}/alpine/${ALPINE_VERSION}/community" >> /etc/apk/repositories && \
  apk --quiet --no-cache update && \
  apk --quiet --no-cache upgrade && \
  apk --quiet --no-cache add ${APK_ADD}

RUN \
  #
  gem install --quiet --no-rdoc --no-ri ${GEMS}

RUN \
  #
  count=$(ls -1 /build/*.gem 2> /dev/null | tail -n1) && \
  if [ ! -z ${count} ] ; then \
    gem install --no-rdoc --no-ri ${count} ; \
  else \
    echo "gem 'grafana', '~> ${GRAFANA_GEM_VERSION}'" >> /build/Gemfile ; \
  fi
  #

RUN \
   #
  cd /build && \
  bundle install

RUN \
  #
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
