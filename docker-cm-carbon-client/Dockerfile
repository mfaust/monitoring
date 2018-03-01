
FROM alpine:3.7

MAINTAINER Bodo Schulz <bodo.schulz@coremedia.com>

ENV \
  VERSION="1803" \
  BUILD_DATE="2018-03-01" \
  TERM=xterm \
  TZ='Europe/Berlin'

# ---------------------------------------------------------------------------------------

RUN \
  apk --quiet --no-cache update && \
  apk --quiet --no-cache upgrade && \
  apk add --quiet --no-cache --virtual .build-deps tzdata && \
  cp /usr/share/zoneinfo/$TZ /etc/localtime && \
  echo $TZ > /etc/timezone && \
  apk del --quiet .build-deps

COPY build /build

RUN \
  apk add --quiet --no-cache --virtual .build-deps \
    build-base imagemagick-dev mariadb-dev ruby-dev ruby-rdoc zlib-dev && \
  apk add --quiet --no-cache \
    bind-tools drill mariadb-client-libs  ruby-irb zlib && \
  echo 'gem: --no-document' >> /etc/gemrc && \
  gem install --quiet --no-rdoc --no-ri \
    io-console bundler && \
  cd /build && \
  bundle install --quiet && \
  for g in $(ls -1 /build/*.gem 2> /dev/null) ; do echo $g; gem install --quiet --no-rdoc --no-ri ${g} ; done && \
  gem uninstall --quiet \
    io-console bundler && \
  apk del --quiet .build-deps && \
  rm -rf \
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
  CMD ps ax | grep -c carbon-data.rb || exit 1

CMD [ "/usr/local/bin/carbon-data.rb" ]
