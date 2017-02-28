
FROM bodsch/docker-ruby

MAINTAINER Bodo Schulz <bodo.schulz@coremedia.com>

LABEL version="1.5.1"

# ---------------------------------------------------------------------------------------

RUN \
  apk --quiet --no-cache update && \
  apk --quiet --no-cache upgrade && \
  apk --quiet --no-cache add \
    build-base \
    supervisor \
    bind-tools \
    collectd \
    collectd-log_logstash \
    imagemagick-dev \
    ruby-dev \
    sqlite-dev \
    sqlite && \
  gem install --no-rdoc --no-ri \
    bigdecimal \
    time_difference \
    filesize \
    rufus-scheduler \
    sqlite3 \
    sequel && \
  mkdir /var/log/monitoring && \
  mkdir /var/cache/monitoring && \
  mv /etc/collectd/collectd.conf /etc/collectd/collectd.conf.dist && \
  apk del --purge \
    build-base \
    imagemagick-dev \
    ruby-dev \
    zlib-dev && \
  rm -rf /var/cache/apk/*

COPY rootfs/ /

CMD [ "/opt/startup.sh" ]
