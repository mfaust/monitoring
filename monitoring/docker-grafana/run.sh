#!/bin/bash

. config.rc

if [ $(docker ps -a | grep ${CONTAINER_NAME} | awk '{print $NF}' | wc -l) -gt 0 ]
then
  docker kill ${CONTAINER_NAME} 2> /dev/null
  docker rm   ${CONTAINER_NAME} 2> /dev/null
fi

GRAPHITE_IP=$(docker inspect --format '{{ .NetworkSettings.IPAddress }}' ${USER}-graphite)
DATABASE_IP=$(docker inspect --format '{{ .NetworkSettings.IPAddress }}' ${USER}-mysql)

[ -z ${DATABASE_IP} ] && { echo "No Database Container '${USER}-mysql' running!"; exit 1; }

DOCKER_DBA_ROOT_PASS=${DOCKER_DBA_ROOT_PASS:-foo.bar.Z}

# ---------------------------------------------------------------------------------------

docker_opts=
docker_opts="${docker_opts} --interactive"
docker_opts="${docker_opts} --tty"
docker_opts="${docker_opts} --detach"
docker_opts="${docker_opts} --publish 3000:3000"
docker_opts="${docker_opts} --volume /etc/localtime:/etc/localtime:ro"
docker_opts="${docker_opts} --link ${USER}-graphite:graphite"
docker_opts="${docker_opts} --link ${USER}-mysql:database"
docker_opts="${docker_opts} --env GRAPHITE_HOST=${GRAPHITE_IP}"
docker_opts="${docker_opts} --env GRAPHITE_PORT=8080"
docker_opts="${docker_opts} --env DATABASE_GRAFANA_TYPE=mysql"
docker_opts="${docker_opts} --env DATABASE_GRAFANA_HOST=${DATABASE_IP}"
docker_opts="${docker_opts} --env DATABASE_GRAFANA_PORT=3306"
docker_opts="${docker_opts} --env DATABASE_ROOT_USER=root"
docker_opts="${docker_opts} --env DATABASE_ROOT_PASS=${DOCKER_DBA_ROOT_PASS}"

# ---------------------------------------------------------------------------------------

docker run \
  ${docker_opts} \
  ${TAG_NAME}

# ---------------------------------------------------------------------------------------
# EOF
