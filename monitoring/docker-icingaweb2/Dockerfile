
FROM docker-alpine-base:latest

MAINTAINER Bodo Schulz <bodo.schulz@coremedia.com>

LABEL version="1.2.0"

ENV TERM xterm

EXPOSE 80

# ---------------------------------------------------------------------------------------

RUN \
  apk --quiet update 

RUN \
  apk --quiet add \
    bash \
    pwgen \
    netcat-openbsd

RUN \
  apk --verbose add \
    icingaweb2

RUN \
  apk --verbose add \
    php-fpm \
    php-pdo \
    php-pdo_mysql \
    php-xml \
    php-dom \
    php-mysqli \
    php-json \
    nginx \
    mysql-client \
    shadow \
    openssl

RUN \
  rm -rf /var/cache/apk/*

RUN \
  usermod -G nginx,icingacmd nginx

RUN \
  mkdir /run/nginx && \
  mkdir /var/log/php-fpm && \
  mkdir /etc/icingaweb2/modules && \
  mkdir /etc/icingaweb2/enabledModules

ADD rootfs/ /

VOLUME  ["/etc/icingaweb2" ]

# Initialize and run Supervisor
ENTRYPOINT [ "/opt/startup.sh" ]

# ---------------------------------------------------------------------------------------
