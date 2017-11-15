
FROM bodsch/docker-icinga2:1711.4

MAINTAINER Bodo Schulz <bodo.schulz@coremedia.com>

ENV \
  VERSION="1711" \
  BUILD_DATE="2017-11-13" \
  TERM=xterm

# ---------------------------------------------------------------------------------------

RUN \
  apk --quiet --no-cache update && \
  apk --quiet --no-cache upgrade

COPY rootfs/ /
COPY build /build

RUN \
  apk add --quiet --no-cache --virtual .build-deps \
    g++ make ruby-dev && \
  apk add --quiet --no-cache \
    py2-pip && \
  gem install --quiet --no-rdoc --no-ri \
    io-console bundler && \
  cd /build && \
  bundle install --quiet && \
  for g in $(ls -1 /build/*.gem 2> /dev/null) ; do echo $g; gem install --quiet --no-rdoc --no-ri ${g} ; done && \
  gem uninstall --quiet \
    io-console bundler && \
  apk del --quiet .build-deps && \
  pip install --quiet --trusted-host http://d.pypi.python.org/simple --upgrade pip && \
  rm -rf \
    /tmp/* \
    /build  \
    /root/.bundle \
    /root/.gem \
    /var/cache/apk/*

HEALTHCHECK \
  --interval=5s \
  --timeout=2s \
  --retries=12 \
  CMD curl --silent --fail localhost:4567/v2/health-check || exit 1
