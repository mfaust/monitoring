
FROM bodsch/docker-alpine-base:alpine-3.5

MAINTAINER Bodo Schulz <bodo.schulz@coremedia.com>

LABEL version="0.9.0"

ENV TERM=xterm

# ---------------------------------------------------------------------------------------

WORKDIR /srv
VOLUME  /srv

RUN \
  apk --quiet --no-cache update && \
  apk --quiet --no-cache upgrade && \
  apk --quiet --no-cache add \
    build-base \
    drill \
    ruby-dev \
    ruby-io-console \
    ruby-rdoc && \
   gem install --no-rdoc --no-ri \
     json \
     rest-client \
     dalli && \
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

ENTRYPOINT [ "/usr/local/bin/external-discover.rb" ]

#CMD /bin/sh
