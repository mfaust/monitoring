#!/bin/bash

. config.rc

if [ $(docker ps -a | grep ${CONTAINER_NAME} | awk '{print $NF}' | wc -l) -gt 0 ]
then
  docker kill ${CONTAINER_NAME} 2> /dev/null
  docker rm   ${CONTAINER_NAME} 2> /dev/null
fi

# ---------------------------------------------------------------------------------------

BLUEPRINT_BOX="192.168.252.100"

HOST_CM7_CMS=${HOST_CM7_CMS:-${BLUEPRINT_BOX}}
HOST_CM7_MLS=${HOST_CM7_MLS:-${BLUEPRINT_BOX}}
HOST_CM7_RLS=${HOST_CM7_RLS:-${BLUEPRINT_BOX}}
HOST_CM7_CONTENTFEEDER=${HOST_CM7_CONTENTFEEDER:-${BLUEPRINT_BOX}}
HOST_CM7_LIVEFEEDER=${HOST_CM7_LIVEFEEDER:-${BLUEPRINT_BOX}}
HOST_CM7_PREVIEWFEEDER=${HOST_CM7_PREVIEWFEEDER:-${BLUEPRINT_BOX}}
HOST_CM7_LIVECAE=${HOST_CM7_LIVECAE:-${BLUEPRINT_BOX}}
HOST_CM7_PREVIEWCAE=${HOST_CM7_PREVIEWCAE:-${BLUEPRINT_BOX}}
HOST_CM7_STUDIO=${HOST_CM7_STUDIO:-${BLUEPRINT_BOX}}
HOST_CM7_SOLR=${HOST_CM7_SOLR:-${BLUEPRINT_BOX}}
HOST_DBA_CMS=${HOST_DBA_CMS:-${BLUEPRINT_BOX}}
HOST_DBA_MLS=${HOST_DBA_MLS:-${BLUEPRINT_BOX}}
HOST_DBA_RLS=${HOST_DBA_RLS:-${BLUEPRINT_BOX}}

# ---------------------------------------------------------------------------------------

JOLOKIA_IP=$(docker inspect --format '{{ .NetworkSettings.IPAddress }}' ${USER}-jolokia   2>/dev/null)
GRAPHITE_IP=$(docker inspect --format '{{ .NetworkSettings.IPAddress }}' ${USER}-graphite 2>/dev/null)
ICINGA2_IP=$(docker inspect --format '{{ .NetworkSettings.IPAddress }}' ${USER}-icinga    2>/dev/null)

# [ -z ${DATABASE_IP} ] && { echo "No Database Container '${USER}-mysql' running!"; exit 1; }

# DNS_CONTAINER="${USER}-dnsmasq"
#
# if [ $(docker inspect --format '{{ .State.Status }}' ${DNS_CONTAINER}) == running ]
# then
#   DOCKER_DNS=$(docker inspect --format '{{ .NetworkSettings.IPAddress }}' ${DNS_CONTAINER})
# else
#   DOCKER_DNS=localhost
# fi

docker_opts=
docker_opts="${docker_opts} --interactive"
docker_opts="${docker_opts} --tty"
docker_opts="${docker_opts} --hostname=${USER}-${TYPE}"
docker_opts="${docker_opts} --name=${CONTAINER_NAME}"
docker_opts="${docker_opts} --env HOST_CM7_CMS=${HOST_CM7_CMS}"
docker_opts="${docker_opts} --env HOST_CM7_MLS=${HOST_CM7_MLS}"
docker_opts="${docker_opts} --env HOST_CM7_RLS=${HOST_CM7_RLS}"
docker_opts="${docker_opts} --env HOST_CM7_CONTENTFEEDER=${HOST_CM7_CONTENTFEEDER}"
docker_opts="${docker_opts} --env HOST_CM7_LIVEFEEDER=${HOST_CM7_LIVEFEEDER}"
docker_opts="${docker_opts} --env HOST_CM7_PREVIEWFEEDER=${HOST_CM7_PREVIEWFEEDER}"
docker_opts="${docker_opts} --env HOST_CM7_LIVECAE=${HOST_CM7_LIVECAE}"
docker_opts="${docker_opts} --env HOST_CM7_PREVIEWCAE=${HOST_CM7_PREVIEWCAE}"
docker_opts="${docker_opts} --env HOST_CM7_STUDIO=${HOST_CM7_STUDIO}"
docker_opts="${docker_opts} --env HOST_CM7_SOLR=${HOST_CM7_SOLR}"
docker_opts="${docker_opts} --env HOST_DBA_CMS=${HOST_DBA_CMS}"
docker_opts="${docker_opts} --env HOST_DBA_MLS=${HOST_DBA_MLS}"
docker_opts="${docker_opts} --env HOST_DBA_RLS=${HOST_DBA_RLS}"
docker_opts="${docker_opts} --volume=${PWD}/inject/usr/local:/usr/local/"

if [ ! -z ${ICINGA2_IP} ]
then
  docker_opts="${docker_opts} --env ICINGA2_HOST=${ICINGA2_IP}"
  docker_opts="${docker_opts} --link=${USER}-icinga:icinga"
fi

if [ ! -z ${GRAPHITE_IP} ]
then
  docker_opts="${docker_opts} --env GRAPHITE_HOST=${GRAPHITE_IP}"
  docker_opts="${docker_opts} --env GRAPHITE_PORT=${GRAPHITE_PORT}"
  docker_opts="${docker_opts} --link=${USER}-graphite:graphite"
fi

if [ ! -z ${JOLOKIA_IP} ]
then
  docker_opts="${docker_opts} --env JOLOKIA_HOST=${JOLOKIA_IP}"
  docker_opts="${docker_opts} --link=${USER}-jolokia:jolokia"
fi

# ---------------------------------------------------------------------------------------

docker run \
  ${docker_opts} \
  ${TAG_NAME} \
  /bin/bash

# docker run \
#   --interactive \
#   --tty \
#   --hostname=${USER}-${TYPE} \
#   --name ${CONTAINER_NAME} \
#   ${TAG_NAME} \
#   /bin/bash

# ---------------------------------------------------------------------------------------
# EOF
