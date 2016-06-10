
FROM docker-alpine-base:latest

MAINTAINER Bodo Schulz <bodo.schulz@coremedia.com>

LABEL version="1.2.2"

ENV TERM xterm

EXPOSE 80

# ---------------------------------------------------------------------------------------

RUN \
  apk --quiet update

RUN \
  apk add \
    icingaweb2

RUN \
  apk --quiet add \
    bash \
    git \
    pwgen \
    netcat-openbsd \
    php5-fpm \
    php5-pdo \
    php5-pdo_mysql \
    php5-xml \
    php5-dom \
    php5-mysqli \
    php5-json \
    nginx \
    mysql-client \
    shadow \
    openssl

RUN \
  cd /usr/share/webapps/icingaweb2/modules && \
  git clone https://github.com/Icinga/icingaweb2-module-director.git director

RUN \
  cd /usr/share/webapps/icingaweb2/modules && \
  git clone https://github.com/Icinga/icingaweb2-module-graphite.git graphite

RUN \
  cd /usr/share/webapps/icingaweb2/modules && \
  git clone https://github.com/Icinga/icingaweb2-module-generictts.git generictts

RUN \
  apk del --purge \
    git && \
  rm -rf /var/cache/apk/*

RUN \
  usermod -G nginx,icingacmd nginx

RUN \
  mkdir /run/nginx && \
  mkdir /var/log/php-fpm && \
  mkdir /etc/icingaweb2/modules && \
  mkdir /etc/icingaweb2/modules/graphite && \
  mkdir /etc/icingaweb2/modules/generictts && \
  mkdir /etc/icingaweb2/enabledModules

RUN \
  /usr/bin/icingacli module enable monitoring && \
  /usr/bin/icingacli module enable setup && \
  /usr/bin/icingacli module enable translation && \
  /usr/bin/icingacli module enable doc && \
  /usr/bin/icingacli module enable director && \
  /usr/bin/icingacli module enable graphite && \
  /usr/bin/icingacli module enable generictts

RUN \
  cp -R /usr/share/webapps/icingaweb2/modules/graphite/sample-config/icinga2/* /etc/icingaweb2/modules/graphite/ && \
  chmod -R 2755 /etc/icingaweb2/modules/graphite

ADD rootfs/ /

VOLUME  ["/etc/icingaweb2" ]

WORKDIR '/etc/icingaweb2'

# Initialize and run Supervisor
ENTRYPOINT [ "/opt/startup.sh" ]

# ---------------------------------------------------------------------------------------
