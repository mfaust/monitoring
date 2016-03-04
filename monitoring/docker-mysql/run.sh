#!/bin/bash

. config.rc

if [ $(docker ps -a | grep ${CONTAINER_NAME} | awk '{print $NF}' | wc -l) -gt 0 ]
then
  docker kill ${CONTAINER_NAME} 2> /dev/null
  docker rm   ${CONTAINER_NAME} 2> /dev/null
fi

# ---------------------------------------------------------------------------------------

docker run \
  --interactive \
  --tty \
  --detach \
  --publish=33060:3306 \
  --env MYSQL_ROOT_PASSWORD=foo.bar.Z \
  --volume=${DATA_DIR}/${TYPE}:/app \
  --dns=${DOCKER_DNS} \
  --hostname=${USER}-${TYPE} \
  --name ${CONTAINER_NAME} \
  ${TAG_NAME}

# ---------------------------------------------------------------------------------------
# EOF