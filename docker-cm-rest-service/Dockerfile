
FROM alpine:3.7

MAINTAINER Bodo Schulz <bodo.schulz@coremedia.com>

ENV \
  VERSION="1712" \
  BUILD_DATE="2017-12-06" \
  http_proxy="http://svc-coremediaweb:Th15Charm1ng-Man@end-bluecoat.next-uk.next.loc:8080/" \
  HTTP_PROXY_AUTH="basic:*:svc-coremediaweb:Th15Charm1ng-Man" \
  TERM=xterm \
  TZ='Europe/Berlin'

# ---------------------------------------------------------------------------------------

RUN \
  apk add --no-cache --virtual .build-deps tzdata && \
  cp /usr/share/zoneinfo/$TZ /etc/localtime && \
  echo $TZ > /etc/timezone && \
  apk del --quiet .build-deps

COPY build /build

RUN \
  apk add --quiet --no-cache --virtual .build-deps \
    build-base imagemagick-dev mariadb-dev ruby-dev ruby-io-console zlib-dev && \
  apk add --quiet --no-cache \
    bind-tools curl drill ipcalc jq mariadb-client mariadb-client-libs ruby-irb ruby-io-console ruby-rdoc zlib && \
  echo 'gem: --no-document' >> /etc/gemrc && \
  gem install --quiet --no-rdoc --no-ri \
    io-console bundler && \
  cd /build && \
  bundle install --quiet && \
  for g in $(ls -1 /build/*.gem 2> /dev/null) ; do echo $g; gem install --no-rdoc --no-ri ${g} ; done && \
  gem uninstall --quiet \
    io-console bundler && \
  apk del --quiet .build-deps && \
  rm -rf \
    /tmp/* \
    /build  \
    /root/.bundle \
    /root/.gem \
    /var/cache/apk/*

COPY rootfs/ /

WORKDIR /

HEALTHCHECK \
  --interval=5s \
  --timeout=2s \
  --retries=12 \
  CMD curl --silent --fail http://localhost:8080/health || exit 1

CMD [ "/init/run.sh" ]
