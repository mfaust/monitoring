
FROM bodsch/docker-ruby

MAINTAINER Bodo Schulz <bodo.schulz@coremedia.com>

LABEL version="1.5.1"

# ---------------------------------------------------------------------------------------

RUN \
  apk --quiet --no-cache update && \
  apk --quiet --no-cache upgrade && \
  gem install --no-rdoc --no-ri \
    beaneater && \
  mkdir /var/log/monitoring && \
  mkdir /var/cache/monitoring && \
  rm -rf /var/cache/apk/*

COPY rootfs/ /

CMD [ "/bin/sh" ]
