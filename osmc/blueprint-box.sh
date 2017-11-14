#!/bin/bash

# set -e

osmc_deploy() {

  hostnamectl set-hostname osmc.local

  if [ $(grep -c domainname /etc/sysctl.conf) -eq 0 ]
  then
    echo "kernel.domainname=local" >> /etc/sysctl.conf
  fi

  sed -i 's|SELINUX=enforcing|SELINUX=permissive|g' /etc/selinux/config

  if [ $(grep -c osmc.local /etc/hosts) -eq 0 ]
  then
    echo "192.168.122.60       osmc.local" >> /etc/hosts
    echo "192.168.122.60       corporate.osmc.local" >> /etc/hosts
    echo "192.168.122.60       preview.osmc.local" >> /etc/hosts
    echo "192.168.122.60       sitemanager.osmc.local" >> /etc/hosts
    echo "192.168.122.60       studio.osmc.local" >> /etc/hosts
    echo "192.168.122.60       overview.osmc.local" >> /etc/hosts
  fi

  systemctl disable firewalld
  systemctl stop firewalld

  yum -y install nano wget unzip yum-utils lynx

  yum -y remove \
    docker \
    docker-common \
    container-selinux \
    docker-selinux \
    docker-engine

  yum-config-manager \
    --add-repo \
    https://download.docker.com/linux/centos/docker-ce.repo

  yum makecache fast

  yum -y install docker-ce

  if [ $? -gt 0 ]
  then
    yum -y install --setopt=obsoletes=0 docker-ce-17.03.2.ce-1.el7.centos.x86_64 docker-ce-selinux-17.03.2.ce-1.el7.centos.noarch
  fi

  service docker start

  systemctl enable docker

  # node_exporter
  docker pull quay.io/prometheus/node-exporter

  docker run \
    --restart=always \
    -d \
    -p 9100:9100 \
    -v "/proc:/host/proc:ro" \
    -v "/sys:/host/sys:ro" \
    -v "/:/rootfs:ro,rslave" \
    --net="host" \
    quay.io/prometheus/node-exporter \
      --path.procfs /host/proc \
      --path.sysfs /host/sys \
      --collector.filesystem.ignored-mount-points "^/(sys|proc|dev|host|etc)($|/)"

  cd /tmp

  if [ $(rpm -aq | grep -c chef) -eq 0 ]
  then
    yum -y install https://packages.chef.io/files/stable/chef/12.8.1/el/7/chef-12.8.1-1.el7.x86_64.rpm
  fi

  if [ $(rpm -aq | grep -c jdk) -eq 0 ]
  then
    wget --no-cookies --no-check-certificate \
      --header "Cookie: gpw_e24=http%3A%2F%2Fwww.oracle.com%2F; oraclelicense=accept-securebackup-cookie" \
      "http://download.oracle.com/otn-pub/java/jdk/8u152-b16/aa0333dd3019491ca4f6ddbe78cdb6d0/jdk-8u152-linux-x64.rpm"

    yum localinstall *.rpm
  fi

  rm -f *.rpm

  [ -d /usr/lib/jvm ] || mkdir -p /usr/lib/jvm
  cd /usr/lib/jvm
  if ! test -L java
  then
    ln -s /usr/java/default java
  fi

  [ -d /var/tmp/deploy ] || mkdir /var/tmp/deploy
  cd /var/tmp/deploy

  rm -rf *

  [ -f /tmp/deployment-archive.zip ] && cp -a /tmp/deployment-archive.zip /var/tmp/deploy/deployment-archive.zip

  [ -f cms.zip ] || curl -L -o cms.zip  "https://repository-build.coremedia.com/nexus/service/local/artifact/maven/redirect?g=com.coremedia.cms.license&a=development-license&v=17-SNAPSHOT&p=zip&r=snapshots.licenses&c=prod"
  [ -f mls.zip ] || curl -L -o mls.zip  "https://repository-build.coremedia.com/nexus/service/local/artifact/maven/redirect?g=com.coremedia.cms.license&a=development-license&v=17-SNAPSHOT&p=zip&r=snapshots.licenses&c=pub"
  [ -f rls.zip ] || curl -L -o rls.zip  "https://repository-build.coremedia.com/nexus/service/local/artifact/maven/redirect?g=com.coremedia.cms.license&a=development-license&v=17-SNAPSHOT&p=zip&r=snapshots.licenses&c=repl"

  # jetzt gehts loooooo ... hos
  [ -f deployment-archive.zip ] && unzip -o deployment-archive.zip

  [ -f /tmp/cms-1710.json ] && cp -a /tmp/cms-1710.json /var/tmp/deploy/chef-repo/nodes/
  [ -f /tmp/osmc-deploy.sh ] && cp -a /tmp/osmc-deploy.sh /var/tmp/deploy/osmc-deploy.sh

  chmod +x /var/tmp/deploy/osmc-deploy.sh

  /var/tmp/deploy/osmc-deploy.sh

  sleep 10s

  /opt/coremedia/content-management-server-tools/bin/cm publishall -a -cq "NOT BELOW PATH '/Home'" -t 1 http://${HOSTNAME}:40180/coremedia/ior admin admin http://${HOSTNAME}:40280/coremedia/ior admin admin
  /opt/coremedia/content-management-server-tools/bin/cm serverimport -r -u admin -p admin --no-validate-xml -t 4 /var/tmp/coremedia/test-data/content

  sleep 4s

  # enable mod_status
  echo "Listen *:8081" >> /etc/httpd/ports.conf
  sed -i 's|ExtendedStatus Off|ExtendedStatus On|g' /etc/httpd/mods-available/status.conf
  sed -i 's|Require local|Require all granted|g' /etc/httpd/sites-available/_overview.conf

  /opt/chef/embedded/bin/ruby /tmp/apache_vhosts.rb > /opt/coremedia/overview/vhosts.json

  service httpd reload

}

after_deploy() {

  sed -i 's|SELINUX=enforcing|SELINUX=permissive|g' /etc/selinux/config

  if [ $(grep -c corporate.osmc.local /etc/hosts) -eq 0 ]
  then
    echo "192.168.122.60       osmc.local" >> /etc/hosts
    echo "192.168.122.60       corporate.osmc.local" >> /etc/hosts
    echo "192.168.122.60       preview.osmc.local" >> /etc/hosts
    echo "192.168.122.60       sitemanager.osmc.local" >> /etc/hosts
    echo "192.168.122.60       studio.osmc.local" >> /etc/hosts
    echo "192.168.122.60       overview.osmc.local" >> /etc/hosts
  fi

  [ -d /tmp/vagrant-cache/yum ] || mkdir -p /tmp/vagrant-cache/yum
  [ -d /var/cache/yum/x86_64 ] || mkdir /var/cache/yum/x86_64

  yum -y update

  yum -y remove \
    docker \
    docker-common \
    container-selinux \
    docker-selinux \
    docker-engine

  yum -y install yum-utils

  yum-config-manager \
    --add-repo \
    https://download.docker.com/linux/centos/docker-ce.repo

  yum makecache fast
  yum -y install --setopt=obsoletes=0 docker-ce-17.03.2.ce-1.el7.centos.x86_64 docker-ce-selinux-17.03.2.ce-1.el7.centos.noarch
  #yum -y install docker-ce

  service docker start

  systemctl enable docker

  # enable mod_status
  yum -y install lynx
  sed -i 's|ExtendedStatus Off|ExtendedStatus On|g' /etc/httpd/mods-available/status.conf
  sed -i 's|Require local|Require all granted|g' /etc/httpd/sites-available/_overview.conf

  # node_exporter
  docker pull quay.io/prometheus/node-exporter

  docker run \
    --restart=always \
    -d \
    -p 9100:9100 \
    -v "/proc:/host/proc:ro" \
    -v "/sys:/host/sys:ro" \
    -v "/:/rootfs:ro,rslave" \
    --net="host" \
    quay.io/prometheus/node-exporter \
      --path.procfs /host/proc \
      --path.sysfs /host/sys \
      --collector.filesystem.ignored-mount-points "^/(sys|proc|dev|host|etc)($|/)"

  #for i in caefeeder-live caefeeder-preview cae-live-1 cae-preview content-feeder content-management-server disable-thp editor-webapp elastic-worker master-live-server replication-live-server sitemanager solr studio user-changes workflow-server; do
  #  systemctl enable $i
  #done
}

reset_hard() {

  for i in caefeeder-live caefeeder-preview cae-live-1 cae-preview content-feeder content-management-server mongod editor-webapp elastic-worker master-live-server replication-live-server sitemanager solr studio user-changes workflow-server mysql-default
  do
    service $i stop
  done

  find /var/log/coremedia/ -type f -exec rm -f {} \;

  yum -y erase mysql-community-common mysql-community-client mysql-community-libs-compat mysql-community-libs mysql-community-server mysql-community-devel

  rm -rf /var/lib/mysql-default
  rm -rf /var/tmp/coremedia
  rm -rf /var/lib/mongo/*
  rm -rf /var/coremedia/solr-data

  cd /var/tmp/deploy

  [ -f deployment-archive.zip ] && unzip -o deployment-archive.zip

  service mongod start

  /var/tmp/deploy/osmc-deploy.sh

  # TODO
  # sed -i 's|#SOLR_HOST="192.168.1.1"|SOLR_HOST=\"${HOSTNAME}\"|g' /etc/default/solr.in.sh
  sed -i 's|ENABLE_REMOTE_JMX_OPTS="false"|ENABLE_REMOTE_JMX_OPTS="true"|g' /opt/solr/bin/solr.in.sh

  service solr restart

  # enable mod_status
  echo "Listen *:8081" >> /etc/httpd/ports.conf
  sed -i 's|ExtendedStatus Off|ExtendedStatus On|g' /etc/httpd/mods-available/status.conf
  sed -i 's|Require local|Require all granted|g' /etc/httpd/sites-available/_overview.conf

  /opt/chef/embedded/bin/ruby /tmp/apache_vhosts.rb > /opt/coremedia/overview/vhosts.json

  service httpd reload

  sleep 10s

#  /opt/coremedia/content-management-server-tools/bin/cm publishall -a -cq "NOT BELOW PATH '/Home'" -t 1 http://${HOSTNAME}:40180/coremedia/ior admin admin http://${HOSTNAME}:40280/coremedia/ior admin admin
#  /opt/coremedia/content-management-server-tools/bin/cm serverimport -r -u admin -p admin --no-validate-xml -t 4 /var/tmp/coremedia/test-data/content
#  sleep 4s

  /opt/coremedia/content-management-server-tools/bin/cm runlevel -u admin -p admin
  /opt/coremedia/master-live-server-tools/bin/cm runlevel -u admin -p admin
  /opt/coremedia/replication-live-server-tools/bin/cm runlevel -u admin -p admin
  /opt/coremedia/replication-live-server-tools/bin/cm runlevel -u admin -p admin -r online -g 2
  /opt/coremedia/caefeeder-preview-tools/bin/cm resetcaefeeder reset
  /opt/coremedia/caefeeder-live-tools/bin/cm resetcaefeeder reset

  service caefeeder-live restart
  service caefeeder-preview restart

  tail -F /var/log/coremedia/*/*log
}


reset_hard

# shutdown -rF now
