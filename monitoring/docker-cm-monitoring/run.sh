#!/bin/bash

. config.rc

if [ $(docker ps -a | grep ${CONTAINER_NAME} | awk '{print $NF}' | wc -l) -gt 0 ]
then
  docker kill ${CONTAINER_NAME} 2> /dev/null
  docker rm   ${CONTAINER_NAME} 2> /dev/null
fi

# ---------------------------------------------------------------------------------------

BLUEPRINT_BOX="192.168.252.100"

HOST_CM7_CMS=${BLUEPRINT_BOX}
HOST_CM7_MLS=${BLUEPRINT_BOX}
HOST_CM7_RLS=${BLUEPRINT_BOX}
HOST_CM7_CONTENTFEEDER=${BLUEPRINT_BOX}
HOST_CM7_LIVEFEEDER=${BLUEPRINT_BOX}
HOST_CM7_PREVIEWFEEDER=${BLUEPRINT_BOX}
HOST_CM7_LIVECAE=${BLUEPRINT_BOX}
HOST_CM7_PREVIEWCAE=${BLUEPRINT_BOX}
HOST_CM7_STUDIO=${BLUEPRINT_BOX}
HOST_DBA_CMS=${BLUEPRINT_BOX}
HOST_DBA_MLS=${BLUEPRINT_BOX}
HOST_DBA_RLS=${BLUEPRINT_BOX}

DNS_CONTAINER="${USER}-dnsmasq"

if [ $(docker inspect --format '{{ .State.Status }}' ${DNS_CONTAINER}) == running ]
then
  DOCKER_DNS=$(docker inspect --format '{{ .NetworkSettings.IPAddress }}' ${DNS_CONTAINER})
else
  DOCKER_DNS=localhost
fi

# ---------------------------------------------------------------------------------------

docker run \
  --interactive \
  --tty \
  --env BLUEPRINT_BOX=${BLUEPRINT_BOX} \
  --env HOST_CM7_CMS=${HOST_CM7_CMS} \
  --env HOST_CM7_MLS=${HOST_CM7_MLS} \
  --env HOST_CM7_RLS=${HOST_CM7_RLS} \
  --env HOST_CM7_CONTENTFEEDER=${HOST_CM7_CONTENTFEEDER} \
  --env HOST_CM7_LIVEFEEDER=${HOST_CM7_LIVEFEEDER} \
  --env HOST_CM7_PREVIEWFEEDER=${HOST_CM7_PREVIEWFEEDER} \
  --env HOST_CM7_LIVECAE=${HOST_CM7_LIVECAE} \
  --env HOST_CM7_PREVIEWCAE=${HOST_CM7_PREVIEWCAE} \
  --env HOST_CM7_STUDIO=${HOST_CM7_STUDIO} \
  --env HOST_DBA_CMS=${HOST_DBA_CMS} \
  --env HOST_DBA_MLS=${HOST_DBA_MLS} \
  --env HOST_DBA_RLS=${HOST_DBA_RLS} \
  --env ICINGA2_HOST=${USER}-icinga2.docker \
  --env JOLOKIA_HOST=${USER}-jolokia.docker \
  --volume=${PWD}/inject/usr/local:/usr/local/ \
  --dns=${DOCKER_DNS} \
  --hostname=${USER}-${TYPE} \
  --name ${CONTAINER_NAME} \
  ${TAG_NAME} \
  /bin/bash

# ---------------------------------------------------------------------------------------
# EOF
