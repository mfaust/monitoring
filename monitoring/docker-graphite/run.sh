#!/bin/bash

. config.rc

if [ $(docker ps -a | grep ${CONTAINER_NAME} | awk '{print $NF}' | wc -l) -gt 0 ]
then
  docker kill ${CONTAINER_NAME} 2> /dev/null
  docker rm   ${CONTAINER_NAME} 2> /dev/null
fi

DATABASE_IP=$(docker inspect --format '{{ .NetworkSettings.IPAddress }}' ${USER}-mysql)

[ -z ${DATABASE_IP} ] && { echo "No Database Container '${USER}-mysql' running!"; exit 1; }

DOCKER_DBA_ROOT_PASS=${DOCKER_DBA_ROOT_PASS:-foo.bar.Z}
DOCKER_DATA_DIR=${DOCKER_DATA_DIR:-${DATA_DIR}}

# ---------------------------------------------------------------------------------------

docker run \
  --interactive \
  --tty \
  --detach \
  --env DATABASE_GRAPHITE_TYPE=mysql \
  --env DATABASE_GRAPHITE_HOST=${DATABASE_IP} \
  --env DATABASE_GRAPHITE_PORT=3306 \
  --env DATABASE_ROOT_USER=root \
  --env DATABASE_ROOT_PASS=${DOCKER_DBA_ROOT_PASS} \
  --publish=2003:2003 \
  --publish=7002:7002 \
  --publish=8088:8080 \
  --volume=${DOCKER_DATA_DIR}/${TYPE}:/app \
  --hostname=${USER}-${TYPE} \
  --name ${CONTAINER_NAME} \
  ${TAG_NAME}

# ---------------------------------------------------------------------------------------
# EOF

