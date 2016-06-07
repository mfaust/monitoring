#!/bin/bash

# set -e
# set -x

SCRIPT=$(readlink -f ${0})
BASE=$(dirname "${SCRIPT}")

. ${BASE}/config.rc

if [ $(docker ps -a | grep ${CONTAINER_NAME} | awk '{print $NF}' | wc -l) -gt 0 ]
then
  docker kill ${CONTAINER_NAME} 2> /dev/null
  docker rm   ${CONTAINER_NAME} 2> /dev/null
fi

DATABASE_IP=$(docker inspect --format '{{ .NetworkSettings.IPAddress }}' ${USER}-mysql)
GRAPHITE_IP=$(docker inspect --format '{{ .NetworkSettings.IPAddress }}' ${USER}-graphite)

[ -z ${DATABASE_IP} ] && { echo "No Database Container '${USER}-mysql' running!"; exit 1; }
[ -z ${GRAPHITE_IP} ] && { echo "No Graphite Container '${USER}-graphite' running!"; exit 1; }

DOCKER_DBA_ROOT_PASS=${DOCKER_DBA_ROOT_PASS:-foo.bar.Z}
DOCKER_IDO_PASS=${DOCKER_IDO_PASS:-1W0svLTg7Q1rKiQrYjdV}
DOCKER_ICINGAWEB_PASS=${DOCKER_ICINGAWEB_PASS:-T7CVdvA0mqzGN6pH5Ne4}
DOCKER_DASHING_API_USER=${DOCKER_DASHING_API_USER:-dashing}
DOCKER_DASHING_API_PASS=${DOCKER_DASHING_API_PASS:-icinga2ondashingr0xx}

# ---------------------------------------------------------------------------------------

docker_opts=
docker_opts="${docker_opts} --interactive"
docker_opts="${docker_opts} --tty"
docker_opts="${docker_opts} --detach"
# docker_opts="${docker_opts} --publish 5665:5665"
# docker_opts="${docker_opts} --publish 6666:6666"
docker_opts="${docker_opts} --hostname ${USER}-${TYPE}"
docker_opts="${docker_opts} --name ${CONTAINER_NAME}"
docker_opts="${docker_opts} --volume /etc/localtime:/etc/localtime:ro"
docker_opts="${docker_opts} --volume ${DOCKER_DATA_DIR}/${TYPE}:/app"
docker_opts="${docker_opts} --volume ${DOCKER_DATA_DIR}/monitoring:/var/cache/monitoring"
docker_opts="${docker_opts} --volume ${BASE}/share/icinga2:/usr/local/monitoring"
docker_opts="${docker_opts} --link ${USER}-mysql:database"
docker_opts="${docker_opts} --link ${USER}-graphite:graphite"
docker_opts="${docker_opts} --add-host=blueprint-box:${BLUEPRINT_BOX}"
docker_opts="${docker_opts} --env MYSQL_HOST=${DATABASE_IP}"
docker_opts="${docker_opts} --env MYSQL_PORT=3306"
docker_opts="${docker_opts} --env MYSQL_USER=root"
docker_opts="${docker_opts} --env MYSQL_PASS=${DOCKER_DBA_ROOT_PASS}"
docker_opts="${docker_opts} --env IDO_PASSWORD=${DOCKER_IDO_PASS}"
docker_opts="${docker_opts} --env CARBON_HOST=${GRAPHITE_IP}"
docker_opts="${docker_opts} --env CARBON_PORT=2003"
docker_opts="${docker_opts} --env DASHING_API_USER=${DOCKER_DASHING_API_USER}"
docker_opts="${docker_opts} --env DASHING_API_PASS=${DOCKER_DASHING_API_PASS}"

if [ ! -z ${DOCKER_DNS} ]
then
  docker_opts="${docker_opts} --dns=${DOCKER_DNS}"
fi

# ---------------------------------------------------------------------------------------

docker run \
  ${docker_opts} \
  ${TAG_NAME}

# ---------------------------------------------------------------------------------------
# EOF
