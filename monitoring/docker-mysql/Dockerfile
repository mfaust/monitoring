
FROM alpine:edge

MAINTAINER Bodo Schulz <bodo@boone-schulz.de>

LABEL version "1.2.0"

EXPOSE 3306

# ---------------------------------------------------------------------------------------

WORKDIR /app
VOLUME  /app

RUN \
  apk --quiet update && \
  apk --quiet upgrade

RUN \
  rm -Rf /var/run && \
  ln -s /run /var/run

RUN \
  apk --quiet add \
    supervisor \
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
