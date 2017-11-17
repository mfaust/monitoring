#!/bin/bash

# set -e

HOSTNAME="osmc.local"

disable_ipv6() {

  sed -i '/^GRUB_CMDLINE_LINUX/d' /etc/default/grub
  echo 'GRUB_CMDLINE_LINUX="rd.lvm.lv=centos_osmc/root rd.lvm.lv=centos_osmc/swap rhgb ipv6.disable=1"' >> /etc/default/grub

  grub2-mkconfig -o /boot/grub2/grub.cfg

  systemctl stop ip6tables
  systemctl disable ip6tables

  sed -i '/^IPV6/d' /etc/sysconfig/network-scripts/ifcfg-*

  echo "net.ipv6.conf.default.disable_ipv6 = 1" > /etc/sysctl.d/99-no-ipv6.conf
  echo "net.ipv6.conf.all.disable_ipv6 = 1" > /etc/sysctl.d/99-no-ipv6.conf

  echo "alias net-pf-10 off" > /etc/modprobe.d/disableip6.conf
  echo "alias ipv6 off" >> /etc/modprobe.d/disableip6.conf
  echo "options ipv6 disable=1" >> /etc/modprobe.d/disableip6.conf
}


prepare() {

  [ "$(hostname -f)" == "${HOSTNAME}"  ] || hostnamectl set-hostname ${HOSTNAME}
  [ $(grep -c domainname /etc/sysctl.conf) -eq 0 ] && echo "kernel.domainname=local" >> /etc/sysctl.conf

  setenforce 0
  sed -i 's|SELINUX=enforcing|SELINUX=permissive|g' /etc/selinux/config

  if [ $(grep -c ${HOSTNAME} /etc/hosts) -eq 0 ]
  then
    echo "192.168.122.60       ${HOSTNAME}" >> /etc/hosts
    echo "192.168.122.60       corporate.${HOSTNAME}" >> /etc/hosts
    echo "192.168.122.60       preview.${HOSTNAME}" >> /etc/hosts
    echo "192.168.122.60       sitemanager.${HOSTNAME}" >> /etc/hosts
    echo "192.168.122.60       studio.${HOSTNAME}" >> /etc/hosts
    echo "192.168.122.60       overview.${HOSTNAME}" >> /etc/hosts
  fi

  systemctl disable firewalld
  systemctl stop firewalld

  yum -y install nano wget unzip yum-utils lynx nc

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
}


wait_for_port() {

  port="${1}"

  RETRY=20

  until [ ${RETRY} -le 0 ]
  do
    echo " [i] waiting for content-server to come up"
    sleep 15s

    nc  ${HOSTNAME} ${port} < /dev/null > /dev/null

    [ $? -eq 0 ] && break

    sleep 10s
    RETRY=$(expr ${RETRY} - 1)
  done
}

wait_for_ior() {

 port="${1}"

  RETRY=20

  until [ ${RETRY} -le 0 ]
  do
    echo " [i] waiting for content-server ior"
    sleep 5s

    curl --fail http://${HOSTNAME}:${port}/coremedia/ior 2> /dev/null
    ecode="${?}"

    echo "${ecode}"

    [ $ecode -eq 0 ] && break

    sleep 10s
    RETRY=$(expr ${RETRY} - 1)
  done
}


deploy() {

  cd /tmp

  [ -f cms.zip ] || curl -L -o cms.zip  "https://repository-build.coremedia.com/nexus/service/local/artifact/maven/redirect?g=com.coremedia.cms.license&a=development-license&v=17-SNAPSHOT&p=zip&r=snapshots.licenses&c=prod"
  [ -f mls.zip ] || curl -L -o mls.zip  "https://repository-build.coremedia.com/nexus/service/local/artifact/maven/redirect?g=com.coremedia.cms.license&a=development-license&v=17-SNAPSHOT&p=zip&r=snapshots.licenses&c=pub"
  [ -f rls.zip ] || curl -L -o rls.zip  "https://repository-build.coremedia.com/nexus/service/local/artifact/maven/redirect?g=com.coremedia.cms.license&a=development-license&v=17-SNAPSHOT&p=zip&r=snapshots.licenses&c=repl"

  if [ $(rpm -aq | grep -c chef) -eq 0 ]
  then
    yum -y install https://packages.chef.io/files/stable/chef/12.8.1/el/7/chef-12.8.1-1.el7.x86_64.rpm
  fi

  if [ $(rpm -aq | grep -c jdk) -eq 0 ]
  then
    wget --no-cookies --no-check-certificate \
      --header "Cookie: gpw_e24=http%3A%2F%2Fwww.oracle.com%2F; oraclelicense=accept-securebackup-cookie" \
      "http://download.oracle.com/otn-pub/java/jdk/8u152-b16/aa0333dd3019491ca4f6ddbe78cdb6d0/jdk-8u152-linux-x64.rpm"

    yum -y localinstall *.rpm
  fi

  rm -f *.rpm

  [ -d /usr/lib/jvm ] || mkdir -p /usr/lib/jvm
  cd /usr/lib/jvm
  if ! test -L java
  then
    ln -s /usr/java/default java
  fi

  [ -d /var/tmp/deploy ] || mkdir /var/tmp/deploy
  [ -d /var/tmp/coremedia ] || mkdir /var/tmp/coremedia


  mkdir -p /var/tmp/coremedia/test-data/content/

  [ -f /tmp/cms9-blueprint-workspace-content-blobs.zip ] && cp /tmp/cms9-blueprint-workspace-content-blobs.zip /var/tmp/coremedia/

  cd /var/tmp/coremedia/
  [ -f cms9-blueprint-workspace-content-blobs.zip ] && unzip -o cms9-blueprint-workspace-content-blobs.zip
  mv workspace/modules/extensions/corporate/test-data/content/__blob  /var/tmp/coremedia/test-data/content/
  cp -u workspace/modules/extensions/am/test-data/content/__blob/*    /var/tmp/coremedia/test-data/content/__blob/


  cd /var/tmp/deploy

  rm -rf *

  [ -f /tmp/deployment-archive.zip ] && cp -a /tmp/deployment-archive.zip /var/tmp/deploy/

  [ -f /tmp/cms.zip ] && cp -a /tmp/cms.zip /var/tmp/deploy/
  [ -f /tmp/mls.zip ] && cp -a /tmp/mls.zip /var/tmp/deploy/
  [ -f /tmp/rls.zip ] && cp -a /tmp/rls.zip /var/tmp/deploy/

  [ -f deployment-archive.zip ] ||  exit 1

  # jetzt gehts loooooo ... hos
  [ -f deployment-archive.zip ] && unzip -o deployment-archive.zip

  [ -f /tmp/cms-1710.json ]  && cp -a /tmp/cms-1710.json  /var/tmp/deploy/chef-repo/nodes/
  [ -f /tmp/cms-1710-deploy.json ]  && cp -a /tmp/cms-1710.json  /var/tmp/deploy/chef-repo/nodes/
  [ -f /tmp/osmc-deploy.sh ] && cp -a /tmp/osmc-deploy.sh /var/tmp/deploy/osmc-deploy.sh
  [ -f /tmp/osmc-content-deploy.sh ] && cp -a /tmp/osmc-deploy.sh /var/tmp/deploy/osmc-content-deploy.sh

  chmod +x /var/tmp/deploy/*.sh

  /var/tmp/deploy/osmc-deploy.sh

  sleep 10s

  # enable mod_status
  echo "Listen *:8081" >> /etc/httpd/ports.conf
  sed -i 's|ExtendedStatus Off|ExtendedStatus On|g' /etc/httpd/mods-available/status.conf
  sed -i 's|Require local|Require all granted|g' /etc/httpd/sites-available/_overview.conf

  /opt/chef/embedded/bin/ruby /tmp/apache_vhosts.rb > /opt/coremedia/overview/vhosts.json

  service httpd reload

  wait_for_port 40180
  wait_for_port 40280

  wait_for_ior 40180
  wait_for_ior 40280

  sleep 1m

  /var/tmp/deploy/osmc-content-deploy.sh

#   /opt/coremedia/content-management-server-tools/bin/cm publishall -a -cq "NOT BELOW PATH '/Home'" -t 1 http://${HOSTNAME}:40180/coremedia/ior admin admin http://${HOSTNAME}:40280/coremedia/ior admin admin
#   /opt/coremedia/content-management-server-tools/bin/cm serverimport -r -u admin -p admin --no-validate-xml -t 4 /var/tmp/coremedia/test-data/content
#
#   /opt/coremedia/content-management-server-tools/bin/cm runlevel -u admin -p admin
#   /opt/coremedia/master-live-server-tools/bin/cm runlevel -u admin -p admin
#   /opt/coremedia/replication-live-server-tools/bin/cm runlevel -u admin -p admin
#   /opt/coremedia/replication-live-server-tools/bin/cm runlevel -u admin -p admin -r online -g 2
#   /opt/coremedia/caefeeder-preview-tools/bin/cm resetcaefeeder reset
#   /opt/coremedia/caefeeder-live-tools/bin/cm resetcaefeeder reset
#
#   service caefeeder-live restart
#   service caefeeder-preview restart
#
#   /opt/coremedia/content-management-server-tools/bin/cm bulkpublish -a -u admin -p admin
#   /opt/coremedia/content-management-server-tools/bin/cm bulkpublish -b -u admin -p admin



}

prepare
deploy
