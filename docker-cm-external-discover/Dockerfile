
FROM bodsch/docker-ruby

MAINTAINER Bodo Schulz <bodo.schulz@coremedia.com>

LABEL version="0.9.2"

ENV TERM=xterm

# ---------------------------------------------------------------------------------------

RUN \
  apk --quiet --no-cache update && \
  apk --quiet --no-cache upgrade && \
  mkdir /var/log/monitoring && \
  apk del --purge \
    build-base \
    supervisor \
    bash \
    nano \
    curl \
    ca-certificates \
    ruby-dev \
    ruby-io-console \
    tree && \
  rm -rf /var/cache/apk/*

COPY rootfs/ /

CMD ["/usr/local/bin/external-discover.rb"]

# ---------------------------------------------------------------------------------------
