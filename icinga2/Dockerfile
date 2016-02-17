# Dockerfile for icinga2 with icingaweb2
# https://github.com/jjethwa/icinga2

FROM debian:jessie

MAINTAINER Bodo Schulz

LABEL version="0.5.1"

ENV DEBIAN_FRONTEND noninteractive

RUN apt-get -qq update && apt-get -qqy upgrade && \
    apt-get -qqy install --no-install-recommends \
      bash \
      sudo \
      procps \
      ca-certificates \
      wget \
      supervisor \
      pwgen \
      unzip \
      ssmtp \
      mailutils \
      vim \
      nano \
      software-properties-common

RUN wget --quiet -O - https://packages.icinga.org/icinga.key | apt-key add - && \
  echo "deb http://packages.icinga.org/debian icinga-jessie-snapshots main" >> /etc/apt/sources.list.d/icinga.list && \
  apt-key adv --recv-keys --keyserver keyserver.ubuntu.com 0xcbcb082a1bb943db && \
  add-apt-repository 'deb [arch=amd64,i386] http://mirrors.n-ix.net/mariadb/repo/10.1/debian jessie main' && \
  apt-get -qq update && \
  apt-get -qqy dist-upgrade && \
  apt-get -qqy install --no-install-recommends \
    apache2 \
    php5-ldap \
    mariadb-server \
    icinga2 \
    icinga2-ido-mysql \
    icinga-web \
    nagios-plugins \
    icingaweb2 \
    curl \
    bc \
    jq \
    yajl-tools && \
  apt-get clean

RUN rm -rf /var/lib/apt/lists/*

# add directory content to docker-container
ADD content/ /

RUN  echo 'root:icingar0xx' | chpasswd; \
 groupadd wheel; \
 useradd --create-home --gid wheel appuser; \
 echo 'appuser:appuser' | chpasswd; \
 sed -i -e 's/^\(%wheel\s\+.\+\)/#\1/gi' /etc/sudoers; \
 echo -e '\n%wheel ALL=(ALL) ALL' >> /etc/sudoers; \
 echo -e '\nDefaults:root   !requiretty' >> /etc/sudoers; \
 echo -e '\nDefaults:%wheel !requiretty' >> /etc/sudoers; \
 echo 'syntax on' >> /root/.vimrc; \
 echo 'alias vi="vim"' >> /root/.bash_profile; \
 echo 'syntax on' >> /home/appuser/.vimrc; \
 echo 'alias vi="vim"' >> /home/appuser/.bash_profile;

# configure PHP timezone
RUN sed -i 's/;date.timezone =/date.timezone = UTC/g' /etc/php5/apache2/php.ini

RUN chmod u+x /opt/supervisor/*_supervisor
# /opt/supervisor/icinga2_supervisor /opt/supervisor/apache2_supervisor
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

VOLUME  ["/etc/icinga2", "/etc/icingaweb2", "/var/lib/mysql", "/var/lib/icinga2" ]

# Initialize and run Supervisor
ENTRYPOINT ["/opt/run"]

