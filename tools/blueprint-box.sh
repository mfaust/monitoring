#!/bin/bash

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

