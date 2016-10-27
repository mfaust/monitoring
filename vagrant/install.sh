#!/bin/bash

set +x

# whoami

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

if [ ! -f /home/vagrant/.ssh/config ]
then

  tee /home/vagrant/.ssh/config <<-'EOF'

Host github.com
  StrictHostKeyChecking no
  ForwardAgent no
  ServerAliveCountMax=30
  ServerAliveInterval=15
EOF

  chown -Rv vagrant: /home/vagrant/.ssh/
  chmod go-rwx /home/vagrant/.ssh/*
  chmod +r /home/vagrant/.ssh/*.pub

fi

# yum clean all
yum -y update
yum -y install docker-engine git



[ -d /srv/docker ] || mkdir -vp /srv/docker

chown vagrant: /srv/docker

cd /srv/docker

if [ ! -d monitoring ]
then

  GIT_TRACE=2
  GIT_CURL_VERBOSE=2
  GIT_TRACE_PERFORMANCE=2
  GIT_TRACE_PACK_ACCESS=2
  GIT_TRACE_PACKET=2
  GIT_TRACE_PACKFILE=2
  GIT_TRACE_SETUP=2
  GIT_TRACE_SHALLOW=2

  GIT_SSH="ssh -i /home/vagrant/.ssh/id_rsa -vv"

  su - vagrant -c ". ~/.bash_profile"

#  su - vagrant -c 'ssh -i /home/vagrant/.ssh/id_rsa -vvT git@github.com'
  su - vagrant -c 'git clone git@github.com:cm-xlabs/monitoring.git'

  if [ ! -d monitoring ]
  then
    echo "git clone not successful"
    exit 1
  fi

  cd monitoring/docker-compose-monitoring
else
  cd monitoring

  git pull
fi

# start dockerd
service docker start

for i in down pull build
do
  /usr/local/bin/docker-compose $i
done

/usr/local/bin/docker-compose up -d



exit 0

