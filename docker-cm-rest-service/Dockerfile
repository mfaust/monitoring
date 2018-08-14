
FROM alpine:3.8

MAINTAINER Bodo Schulz <bodo.schulz@coremedia.com>

ENV \
  VERSION="1807" \
  BUILD_DATE="2018-07-30" \
  TERM=xterm \
  TZ='Europe/Berlin'

# ---------------------------------------------------------------------------------------

COPY build /build

RUN \
  apk --quiet --no-cache update && \
  apk --quiet --no-cache upgrade && \
  apk add --quiet --no-cache --virtual .build-deps \
    build-base imagemagick-dev mariadb-dev ruby-dev ruby-io-console zlib-dev && \
  apk add --quiet --no-cache \
    bind-tools curl drill ipcalc jq mariadb-connector-c mariadb-client ruby-irb ruby-io-console ruby-rdoc tzdata zlib && \
  echo 'gem: --no-document' >> /etc/gemrc && \
  gem install --quiet --no-rdoc --no-ri \
    io-console bundler json && \
  cp /usr/share/zoneinfo/${TZ} /etc/localtime && \
  echo ${TZ} > /etc/timezone && \
  cd /build && \
  for g in $(ls -1 /build/*.gem 2> /dev/null) ; do echo $g; gem install --no-rdoc --no-ri ${g} ; done && \
  bundle install --quiet && \
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
