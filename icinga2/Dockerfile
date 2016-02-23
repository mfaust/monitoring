# Dockerfile for icinga2 with icingaweb2
# https://github.com/jjethwa/icinga2

FROM debian:jessie

MAINTAINER Bodo Schulz

LABEL version="0.6.2"

ENV DEBIAN_FRONTEND noninteractive
ENV TERM xterm

RUN apt-get -qq update && \
  apt-get -qqy install \
    ca-certificates \
    wget \
    software-properties-common && \
  wget --quiet -O - http://debmon.org/debmon/repo.key 2>/dev/null | apt-key add - && \
  wget --quiet -O - https://packages.icinga.org/icinga.key | apt-key add - && \
  echo "deb http://debmon.org/debmon debmon-wheezy main" >/etc/apt/sources.list.d/debmon.list && \
  echo "deb http://packages.icinga.org/debian icinga-jessie-snapshots main" >> /etc/apt/sources.list.d/icinga.list && \
  apt-key adv --recv-keys --keyserver keyserver.ubuntu.com 0xcbcb082a1bb943db && \
  add-apt-repository 'deb [arch=amd64,i386] http://mirrors.n-ix.net/mariadb/repo/10.1/debian jessie main' && \
  apt-get -qq update && \
  apt-get -qqy upgrade && \
  apt-get -qqy dist-upgrade && \
  apt-get -qqy install --no-install-recommends \
    bash \
    sudo \
    procps \
    fping \
    cron \
    supervisor \
    pwgen \
    unzip \
    ssmtp \
    mailutils \
    nano \
    nmap \
    php5-mysqlnd \
    php5-fpm \
    nginx \
    mariadb-server \
    icinga2 \
    icinga2-ido-mysql \
    monitoring-plugins \
    icingaweb2 \
    curl \
    bc \
    jq \
    yajl-tools && \
  apt-get clean  && \
  rm -rf /var/lib/apt/lists/* && \
  dd if=/dev/zero of=dummy bs=500M count=1 && rm -f dummy

RUN wget --no-cookies --quiet  https://opscode-omnibus-packages.s3.amazonaws.com/debian/6/x86_64/chefdk_0.10.0-1_amd64.deb --output-document=/tmp/chefdk_0.10.0-1_amd64.deb && \
  dpkg -i /tmp/chefdk_0.10.0-1_amd64.deb && \
  rm --force /tmp/chefdk_0.10.0-1_amd64.deb && \
  dd if=/dev/zero of=dummy bs=500M count=1 && rm -f dummy

# add directory content to docker-container
ADD content/ /

RUN rm -f /etc/nginx/sites-enabled/default 2> /dev/null ; \
  mkdir -p /var/log/nginx/icingaweb

RUN chmod u+x /opt/supervisor/*_supervisor
RUN chmod u+x /opt/run

# Temporary hack to get icingaweb2 modules via git
RUN mkdir --parents /etc/icingaweb2/enabledModules && \
  wget --no-cookies --quiet "https://github.com/Icinga/icingaweb2/archive/master.zip" --output-document=/tmp/icingaweb2.zip && \
  unzip -qq /tmp/icingaweb2.zip "icingaweb2-master/modules/doc/*" "icingaweb2-master/modules/monitoring/*" -d "/tmp/icingaweb2" && \
  cp --recursive  /tmp/icingaweb2/icingaweb2-master/modules/monitoring /etc/icingaweb2/modules/ && \
  cp --recursive  /tmp/icingaweb2/icingaweb2-master/modules/doc /etc/icingaweb2/modules/ && \
  rm --recursive --force /tmp/icingaweb2.zip /tmp/icingaweb2

# ports (icinga2 api & cluster (5665), mysql (3306))
EXPOSE 80 443 5665

RUN \
    dd if=/dev/zero of=dummy bs=500M count=1 && \
    rm -f dummy

VOLUME  ["/etc/icinga2", "/etc/icingaweb2", "/var/lib/mysql", "/var/lib/icinga2" ]

# Initialize and run Supervisor
ENTRYPOINT ["/opt/run"]
