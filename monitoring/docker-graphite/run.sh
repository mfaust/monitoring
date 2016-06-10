#!/bin/bash

. config.rc

if [ $(docker ps -a | grep ${CONTAINER_NAME} | awk '{print $NF}' | wc -l) -gt 0 ]
then
  docker kill ${CONTAINER_NAME} 2> /dev/null
  docker rm   ${CONTAINER_NAME} 2> /dev/null
fi

DATABASE_IP=$(docker inspect --format '{{ .NetworkSettings.IPAddress }}' ${USER}-mysql)

[ -z ${DATABASE_IP} ] && { echo "No Database Container '${USER}-mysql' running!"; exit 1; }

# ---------------------------------------------------------------------------------------

docker_opts=
docker_opts="${docker_opts} --interactive"
docker_opts="${docker_opts} --tty"
docker_opts="${docker_opts} --detach"
#docker_opts="${docker_opts} --publish 2003:2003"
#docker_opts="${docker_opts} --publish 7002:7002"
#docker_opts="${docker_opts} --publish 8088:8080"
docker_opts="${docker_opts} --hostname ${USER}-${TYPE}"
docker_opts="${docker_opts} --name ${CONTAINER_NAME}"
docker_opts="${docker_opts} --volume /etc/localtime:/etc/localtime:ro"
docker_opts="${docker_opts} --volume ${DOCKER_DATA_DIR}/${TYPE}:/app:rw"
docker_opts="${docker_opts} --env DATABASE_GRAPHITE_TYPE=mysql"
docker_opts="${docker_opts} --env DATABASE_GRAPHITE_HOST=${DATABASE_IP}"
docker_opts="${docker_opts} --env DATABASE_GRAPHITE_PORT=3306"
docker_opts="${docker_opts} --env DATABASE_GRAPHITE_PASS=${DOCKER_GRAPHITE_DBA_PASS}"
docker_opts="${docker_opts} --env DATABASE_ROOT_USER=root"
docker_opts="${docker_opts} --env DATABASE_ROOT_PASS=${DOCKER_DBA_ROOT_PASS}"

# ---------------------------------------------------------------------------------------

docker run \
  ${docker_opts} \
  ${TAG_NAME}

# ---------------------------------------------------------------------------------------
# EOF

