#!/bin/bash

. config.rc

if [ $(docker ps -a | grep ${CONTAINER_NAME} | awk '{print $NF}' | wc -l) -gt 0 ]
then
  docker kill ${CONTAINER_NAME} 2> /dev/null
  docker rm   ${CONTAINER_NAME} 2> /dev/null
fi

DOCKER_DBA_ROOT_PASS=${DOCKER_DBA_ROOT_PASS:-foo.bar.Z}
DOCKER_DATA_DIR=${DOCKER_DATA_DIR:-${DATA_DIR}}

# ---------------------------------------------------------------------------------------

docker_opts=
docker_opts="${docker_opts} --interactive"
docker_opts="${docker_opts} --tty"
docker_opts="${docker_opts} --detach"
docker_opts="${docker_opts} --hostname ${USER}-${TYPE}"
docker_opts="${docker_opts} --name ${CONTAINER_NAME}"
docker_opts="${docker_opts} --volume /etc/localtime:/etc/localtime:ro"
docker_opts="${docker_opts} --volume=${DOCKER_DATA_DIR}/${TYPE}:/app"
docker_opts="${docker_opts} --env MYSQL_ROOT_PASSWORD=${DOCKER_DBA_ROOT_PASS}"

# ---------------------------------------------------------------------------------------

docker run \
  ${docker_opts} \
  ${TAG_NAME}

# ---------------------------------------------------------------------------------------
# EOF
