#!/bin/bash

# set -x

[ -f config.rc ] && . config.rc

SRC_BASE=${PWD}
export USER=${USER:-'user'}

MONITORING_CONTAINER="docker-alpine-base docker-nginx docker-mysql docker-jolokia docker-graphite docker-icinga2 docker-icingaweb2 docker-grafana docker-dashing docker-cm-monitoring"

createDataDir() {

  if [ ! -z ${DOCKER_DATA_DIR} ]
  then
    mkdir -p ${DOCKER_DATA_DIR}
  else
    echo "please configure a 'DOCKER_DATA_DIR'!"
    exit 1
  fi
}

buildContainer() {

  echo -e "\n"

  for d in ${MONITORING_CONTAINER}
  do
    if [ -x ${SRC_BASE}/${d}/build.sh ]
    then

      cd ${SRC_BASE}/${d}

      echo " => build Container '${d}' ..."

      ./build.sh

    else
      echo "no build script for Container '${d}' found"
    fi

    echo -e "\n =========================================================== \n"
  done

  echo -e " ... done\n\n"
}

createDataDir

buildContainer

exit 0

# EOF
