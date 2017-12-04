#!/bin/bash

sed -i 's|SELINUX=enforcing|SELINUX=permissive|g' /etc/selinux/config

if [ $(grep -c corporate.blueprint-box /etc/hosts) -eq 0 ]
then
  echo "127.0.0.1       corporate.blueprint-box" >> /etc/hosts
  echo "127.0.0.1       preview.blueprint-box" >> /etc/hosts
  echo "127.0.0.1       sitemanager.blueprint-box" >> /etc/hosts
  echo "127.0.0.1       studio.blueprint-box" >> /etc/hosts
  echo "127.0.0.1       overview.blueprint-box" >> /etc/hosts
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
yum -y install docker-ce

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

for i in caefeeder-live caefeeder-preview cae-live-1 cae-preview content-feeder content-management-server disable-thp editor-webapp elastic-worker master-live-server replication-live-server sitemanager solr studio user-changes workflow-server; do
  systemctl enable $i
done

shutdown -rF now
