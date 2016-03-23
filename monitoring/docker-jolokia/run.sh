#!/bin/bash

. config.rc

if [ $(docker ps -a | grep ${CONTAINER_NAME} | awk '{print $NF}' | wc -l) -gt 0 ]
then
  docker kill ${CONTAINER_NAME} 2> /dev/null
  docker rm   ${CONTAINER_NAME} 2> /dev/null
fi

DOCKER_DNS=${DOCKER_DNS:-""}

docker_opts=
docker_opts="${docker_opts} --interactive"
docker_opts="${docker_opts} --tty"
docker_opts="${docker_opts} --detach"
docker_opts="${docker_opts} --hostname=${USER}-${TYPE}"
docker_opts="${docker_opts} --name=${CONTAINER_NAME}"

if [ ! -z ${DOCKER_DNS} ]
then
  docker_opts="${docker_opts} --dns ${DOCKER_DNS}"
fi

# ---------------------------------------------------------------------------------------

docker run \
  ${docker_opts} \
  ${TAG_NAME}

# ---------------------------------------------------------------------------------------
# EOF
