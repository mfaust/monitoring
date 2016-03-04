FROM alpine:3.3

MAINTAINER Bodo Schulz <bodo@boone-schulz.de>

LABEL version "1.1.0"

EXPOSE 3306

# ---------------------------------------------------------------------------------------

WORKDIR /app
VOLUME  /app

RUN \
  apk update && \
  apk upgrade && \
  apk add \
    supervisor \
    mysql \
    mysql-client \
    pwgen && \
  rm -rf /tmp/* /var/cache/apk/*

ADD rootfs/ /

CMD [ "/opt/startup.sh" ]

# ---------------------------------------------------------------------------------------
