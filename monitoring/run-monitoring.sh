#!/bin/bash

# set -x

[ -d config.rc ] && . config.rc

SRC_BASE=${PWD}

MONITORING_CONTAINER="docker-mysql docker-jolokia docker-graphite docker-icinga2 docker-icingaweb2 docker-grafana docker-dashing"

export DOCKER_DNS="10.1.2.63"
# export DATA_DIR="/srv/docker/data"

#if [ ! -d ${DATA_DIR} ]
#then
#  mkdir -p ${DATA_DIR}
#fi

runContainer() {

  echo -e "\n"

  for d in ${MONITORING_CONTAINER}
  do
    if [ -x ${SRC_BASE}/${d}/run.sh ]
    then
      cd ${SRC_BASE}/${d}

      . ./config.rc

      echo " => starting Container '${d}' named ${CONTAINER_NAME} ..."

      ./run.sh > /dev/null

      if [ ${MONITOR_DOCKER_CONTAINER} == true ]
      then
        sleep 4s

        IP=$(docker inspect --format '{{ .NetworkSettings.IPAddress }}' ${CONTAINER_NAME})
        NAME=$(docker inspect --format '{{ .Config.Hostname }}' ${CONTAINER_NAME})

        ICINGA_API="$(readlink -f ../tools/bin/icinga-api.sh)"
        ${ICINGA_API} --filter "docker-nod*" --address "${IP}" --name "${NAME}"
      fi
    else
      echo "no run.sh found"
    fi

    echo -e "\n =========================================================== \n"
  done

#  sleep 5s

  echo -e " ... done\n\n"
}

runContainer

exit 0

# EOF
