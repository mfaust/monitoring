#!/bin/bash

. config.rc

if [ $(docker ps -a | grep ${CONTAINER_NAME} | awk '{print $NF}' | wc -l) -gt 0 ]
then
  docker kill ${CONTAINER_NAME} 2> /dev/null
  docker rm   ${CONTAINER_NAME} 2> /dev/null
fi

# ---------------------------------------------------------------------------------------

docker_opts="${docker_opts} --interactive"
docker_opts="${docker_opts} --tty"
docker_opts="${docker_opts} --detach"
docker_opts="${docker_opts} --publish 80:80"
docker_opts="${docker_opts} --hostname ${USER}-${TYPE}"
docker_opts="${docker_opts} --name ${CONTAINER_NAME}"
docker_opts="${docker_opts} --volume /etc/localtime:/etc/localtime:ro"
docker_opts="${docker_opts} --link ${USER}-icingaweb2:icingaweb2"
docker_opts="${docker_opts} --link ${USER}-grafana:grafana"
docker_opts="${docker_opts} --link ${USER}-dashing:dashing"

# ---------------------------------------------------------------------------------------

docker run \
  ${docker_opts} \
  ${TAG_NAME}

# ---------------------------------------------------------------------------------------
# EOF
