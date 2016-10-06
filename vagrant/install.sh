#!/bin/bash

if [ ! -f /etc/yum.repos.d/docker.repo ]
then
  tee /etc/yum.repos.d/docker.repo <<-'EOF'
[dockerrepo]
name=Docker Repository
baseurl=https://yum.dockerproject.org/repo/main/centos/7/
enabled=1
gpgcheck=1
gpgkey=https://yum.dockerproject.org/gpg
EOF
fi

if [ ! -f /usr/local/bin/docker-compose ]
then
  curl -L https://github.com/docker/compose/releases/download/1.8.1/docker-compose-`uname -s`-`uname -m` > /usr/local/bin/docker-compose && chmod +x /usr/local/bin/docker-compose
fi

yum clean all
yum -y update
yum -y install docker-engine git

# install coremedia specific stuff here

service docker start

[ -d /srv/docker ] || mkdir -vp /srv/docker

cd /srv/docker

if [ ! -d monitoring ]
then
  git clone https://github.com/cm-xlabs/monitoring.git .

  cd monitoring/docker-compose-monitoring
else
  cd monitoring

  git pull
fi

for i in down pull build; do docker-compose $i; done

docker-compose up -d



exit 0

