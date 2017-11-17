
FROM alpine:3.6

MAINTAINER Bodo Schulz <bodo.schulz@coremedia.com>

ENV \
  VERSION="1711" \
  BUILD_DATE="2017-11-13" \
  TERM=xterm \
  TZ='Europe/Berlin' \
  ICINGA2_GEM_TYPE="local" \
  ICINGA2_GEM_VERSION="1.0"

# ---------------------------------------------------------------------------------------

RUN \
  apk --quiet --no-cache update && \
  apk --quiet --no-cache upgrade

COPY build /build

RUN \
  apk add --quiet --no-cache --virtual .build-deps \
    build-base git ruby-dev ruby-rdoc && \
  apk --quiet --no-cache add \
    bind-tools curl drill mariadb-dev mariadb-client-libs jq libressl-dev ruby-irb &&\
  echo 'gem: --no-document' >> /etc/gemrc && \
  gem install --quiet --no-rdoc --no-ri \
    io-console bundler && \
  cd /build && \
  bundle install --quiet && \
  for g in $(ls -1 /build/*.gem 2> /dev/null) ; do echo $g; gem install --quiet --no-rdoc --no-ri ${g} ; done && \
  if [ "${ICINGA2_GEM_TYPE}" == "stable" ] ; then \
    echo "gem 'icinga2', '~> ${ICINGA2_GEM_VERSION}'" >> Gemfile ; \
  fi && \
  gem uninstall --quiet \
    io-console bundler && \
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
