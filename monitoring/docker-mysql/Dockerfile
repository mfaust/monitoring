
FROM docker-alpine-base:latest

MAINTAINER Bodo Schulz <bodo.schulz@coremedia.com>

LABEL version "1.4.0"

EXPOSE 3306

# ---------------------------------------------------------------------------------------

WORKDIR /app
VOLUME  /app

RUN \
  apk --quiet update

RUN \
  apk --quiet add \
    collectd \
    collectd-mysql \
    mysql \
    mysql-client \
    pwgen

RUN \
  rm -rf /tmp/* /var/cache/apk/*

RUN \
  mv /etc/collectd/collectd.conf /etc/collectd/collectd.conf.DIST

ADD rootfs/ /

CMD [ "/opt/startup.sh" ]

# ---------------------------------------------------------------------------------------
