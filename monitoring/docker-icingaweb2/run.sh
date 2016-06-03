#!/bin/bash

. config.rc

if [ $(docker ps -a | grep ${CONTAINER_NAME} | awk '{print $NF}' | wc -l) -gt 0 ]
then
  docker kill ${CONTAINER_NAME} 2> /dev/null
  docker rm   ${CONTAINER_NAME} 2> /dev/null
fi

DATABASE_IP=$(docker inspect --format '{{ .NetworkSettings.IPAddress }}' ${USER}-mysql)
GRAPHITE_IP=$(docker inspect --format '{{ .NetworkSettings.IPAddress }}' ${USER}-graphite)
ICINGA2_IP=$(docker inspect --format '{{ .NetworkSettings.IPAddress }}' ${USER}-icinga2)

[ -z ${DATABASE_IP} ] && { echo "No Database Container '${USER}-mysql' running!"; exit 1; }
[ -z ${GRAPHITE_IP} ] && { echo "No Graphite Container '${USER}-graphite' running!"; exit 1; }
[ -z ${ICINGA2_IP} ] && { echo "No Icinga2 Container '${USER}-icinga2' running!"; exit 1; }

DOCKER_DBA_ROOT_PASS=${DOCKER_DBA_ROOT_PASS:-foo.bar.Z}
DOCKER_IDO_PASS=${DOCKER_IDO_PASS:-1W0svLTg7Q1rKiQrYjdV}
DOCKER_ICINGAWEB_PASS=${DOCKER_ICINGAWEB_PASS:-T7CVdvA0mqzGN6pH5Ne4}

# ---------------------------------------------------------------------------------------

docker_opts="${docker_opts} --interactive"
docker_opts="${docker_opts} --tty"
docker_opts="${docker_opts} --detach"
# docker_opts="${docker_opts} --publish 80:80"
docker_opts="${docker_opts} --hostname ${USER}-${TYPE}"
docker_opts="${docker_opts} --name ${CONTAINER_NAME}"
docker_opts="${docker_opts} --volume /etc/localtime:/etc/localtime:ro"
docker_opts="${docker_opts} --volume ${PWD}/share/icinga2:/usr/local/share/icinga2"
docker_opts="${docker_opts} --volumes-from ${USER}-icinga2"
docker_opts="${docker_opts} --link ${USER}-mysql:database"
docker_opts="${docker_opts} --link ${USER}-icinga2:icinga2"
docker_opts="${docker_opts} --env MYSQL_HOST=${DATABASE_IP}"
docker_opts="${docker_opts} --env MYSQL_PORT=3306"
docker_opts="${docker_opts} --env MYSQL_USER=root"
docker_opts="${docker_opts} --env MYSQL_PASS=${DOCKER_DBA_ROOT_PASS}"
docker_opts="${docker_opts} --env IDO_PASSWORD=${DOCKER_IDO_PASS}"
docker_opts="${docker_opts} --env ICINGAWEB2_PASSWORD=${DOCKER_ICINGAWEB_PASS}"
docker_opts="${docker_opts} --env ICINGAADMIN_USER=icinga"
docker_opts="${docker_opts} --env ICINGAADMIN_PASS=icinga"
docker_opts="${docker_opts} --env LIVESTATUS_HOST=${ICINGA2_IP}"
docker_opts="${docker_opts} --env LIVESTATUS_PORT=6666"

# ---------------------------------------------------------------------------------------

docker run \
  ${docker_opts} \
  ${TAG_NAME}

# ---------------------------------------------------------------------------------------
# EOF
