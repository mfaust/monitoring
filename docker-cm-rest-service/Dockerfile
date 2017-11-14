
FROM alpine:3.6

MAINTAINER Bodo Schulz <bodo.schulz@coremedia.com>

ENV \
  VERSION="1711" \
  BUILD_DATE="2017-11-14" \
  TERM=xterm

# ---------------------------------------------------------------------------------------

RUN \
  apk --no-cache update && \
  apk --no-cache upgrade

COPY build /build

RUN \
  apk add --quiet --no-cache --virtual .build-deps \
    build-base imagemagick-dev mariadb-dev ruby-dev ruby-io-console zlib-dev && \
  apk --no-cache add \
    bind-tools curl drill ipcalc jq mariadb-client mariadb-client-libs ruby-irb ruby-io-console ruby-rdoc zlib && \
  gem install --quiet --no-rdoc --no-ri \
    bundler \
    io-console && \
  cd /build && \
  bundle install && \
  count=$(ls -1 /build/*.gem 2> /dev/null) && \
  if [ ! -z ${count} ] ; then \
    gem install --no-rdoc --no-ri ${count} ; \
  fi && \
  apk del --quiet .build-deps && \
  rm -rf \
    /tmp/* \
    /root/.bundle \
    /root/.gem \
    /var/cache/apk/*

COPY rootfs/ /

WORKDIR /

HEALTHCHECK \
  --interval=5s \
  --timeout=2s \
  --retries=12 \
  CMD curl --silent --fail http://localhost:4567/health || exit 1

CMD [ "/init/run.sh" ]
