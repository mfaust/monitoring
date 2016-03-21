#!/bin/bash

# set -x

SRC_BASE=${PWD}

MONITORING_CONTAINER="docker-mysql docker-jolokia docker-graphite docker-icinga2 docker-icingaweb2 docker-grafana docker-dashing"

DOCKER_DNS="172.17.0.1"
DOCKER_ADDN_DIR="/tmp"

rm -f ${DOCKER_ADDN_DIR}/dnsmasq.addn.docker

runDNSDocker() {

  cd ${SRC_BASE}/docker-dnsmasq

  . ./config.rc

  echo " => starting DNS Container '${CONTAINER_NAME}' ..."

  ./run.sh > /dev/null

  IP=$(docker inspect --format '{{ .NetworkSettings.IPAddress }}' ${CONTAINER_NAME})
  NAME=$(docker inspect --format '{{ .Config.Hostname }}' ${CONTAINER_NAME})

  echo "starting Docker DNS with IP ${IP}"

  export DOCKER_DNS=${IP}
  export DOCKER_ADDN_DIR="/tmp"
}


runContainer() {

  for d in ${MONITORING_CONTAINER}
  do
    if [ -x ${SRC_BASE}/${d}/run.sh ]
    then
      cd ${SRC_BASE}/${d}

      . ./config.rc

      echo " => starting Container '${d}' named ${CONTAINER_NAME} ..."

      ./run.sh > /dev/null
    else
      echo "no run.sh found"
    fi

    echo -e "\n =========================================================== \n"
  done

  sleep 15s
}

runContainer

cd ${SRC_BASE}

for CID in $(docker ps -q)
do
  IP=$(docker inspect --format '{{ .NetworkSettings.IPAddress }}' ${CID})
  NAME=$(docker inspect --format '{{ .Config.Hostname }}' ${CID})

  echo " - '${IP}' - '${NAME}'"

  echo "${IP}  ${NAME}" >> ${DOCKER_ADDN_DIR}/dnsmasq.addn.docker

  tools/bin/icinga-api.sh --filter "docker-nod*" --address "${IP}" --name "${NAME}"
done

exit 0




export DOCKER_DNS=${IP}
export DOCKER_ADDN_DIR="/tmp"

for d in ${MONITORING_CONTAINER}
do
  if [ -x ${SRC_BASE}/${d}/run.sh ]
  then
    cd ${SRC_BASE}/${d}

    . ./config.rc

    echo " => starting Container '${d}' named ${CONTAINER_NAME} ..."

    ./run.sh > /dev/null
  else
    echo "no run.sh found"
  fi

  echo -e "\n =========================================================== \n"
done

for CID in docker-dnsmasq ${MONITORING_CONTAINER} 
do
  IP=$(docker inspect --format '{{ .NetworkSettings.IPAddress }}' ${CID})
  NAME=$(docker inspect --format '{{ .Config.Hostname }}' ${CID})
  echo "${IP}  ${NAME}.${CONTAINER_DOMAIN}" >> ${DOCKER_ADDN_DIR}/dnsmasq.addn.docker
done

cd ${SRC_BASE}

for CID in $(docker ps -q)
do
  IP=$(docker inspect --format '{{ .NetworkSettings.IPAddress }}' ${CID})
  NAME=$(docker inspect --format '{{ .Config.Hostname }}' ${CID})

  tools/bin/icinga-api.sh --filter "docker-nod*" --address "${IP}" --name "${NAME}.${CONTAINER_DOMAIN}"
done

#[ -x /usr/local/bin/update-docker-dns.sh ] && sudo /usr/local/bin/update-docker-dns.sh

# EOF
