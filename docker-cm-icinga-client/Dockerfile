
FROM alpine:3.6

MAINTAINER Bodo Schulz <bodo.schulz@coremedia.com>

ENV \
  VERSION="1711" \
  BUILD_DATE="2017-11-13" \
  ALPINE_MIRROR="mirror1.hs-esslingen.de/pub/Mirrors" \
  ALPINE_VERSION="v3.6" \
  TERM=xterm \
  ICINGA2_GEM_VERSION="1.0"

# ---------------------------------------------------------------------------------------

COPY build /build

RUN \
  echo "http://${ALPINE_MIRROR}/alpine/${ALPINE_VERSION}/main"       > /etc/apk/repositories && \
  echo "http://${ALPINE_MIRROR}/alpine/${ALPINE_VERSION}/community" >> /etc/apk/repositories && \
  apk update --quiet --no-cache && \
  apk upgrade --quiet --no-cache && \
  apk add --quiet --no-cache --virtual .build-deps \
    build-base git ruby-dev ruby-rdoc && \
  apk --quiet --no-cache add \
    bind-tools curl drill mariadb-dev jq libressl-dev ruby-irb &&\
  echo 'gem: --no-document' >> /etc/gemrc && \
  gem install --quiet --no-rdoc --no-ri \
    io-console bundler && \
  count=$(ls -1 /build/*.gem 2> /dev/null | tail -n1) && \
  if [ ! -z ${count} ] ; then \
    gem install --quiet --no-rdoc --no-ri ${count} ; \
  else \
    echo "gem 'icinga2', '~> ${ICINGA2_GEM_VERSION}'" >> /build/Gemfile ; \
  fi && \
  cd /build && \
  bundle install --quiet && \
  apk del --quiet .build-deps && \
  rm -rf \
    /opt/* \
    /tmp/* \
    /build \
    /root/.bundle \
    /root/.gem \
    /var/cache/apk/*

COPY rootfs/ /

WORKDIR /

HEALTHCHECK \
  --interval=5s \
  --timeout=2s \
  --retries=12 \
  CMD ps ax | grep -c icinga-client.rb || exit 1

ENTRYPOINT [ "/init/run.sh" ]

CMD [ "/usr/local/bin/icinga-client.rb" ]
