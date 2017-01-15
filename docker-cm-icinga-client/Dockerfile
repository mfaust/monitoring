
FROM bodsch/docker-ruby

MAINTAINER Bodo Schulz <bodo.schulz@coremedia.com>

LABEL version="1.5.1"

# ---------------------------------------------------------------------------------------

RUN \
  apk --quiet --no-cache update && \
  apk --quiet --no-cache upgrade && \
  apk --quiet --no-cache add \
    build-base \
    ruby-dev && \
  gem install --no-rdoc --no-ri \
    rest-client && \
  mkdir /var/log/monitoring && \
  mkdir /var/cache/monitoring && \
  apk del --purge \
    build-base \
    ruby-dev && \
  rm -rf /var/cache/apk/*

COPY rootfs/ /

CMD [ "/bin/sh" ]
