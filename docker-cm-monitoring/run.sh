#!/bin/bash

SCRIPT=$(readlink -f ${0})
BASE=$(dirname "${SCRIPT}")

. ${BASE}/config.rc

if [ $(docker ps -a | grep ${CONTAINER_NAME} | awk '{print $NF}' | wc -l) -gt 0 ]
then
  docker kill ${CONTAINER_NAME} 2> /dev/null
  docker rm   ${CONTAINER_NAME} 2> /dev/null
fi

# ---------------------------------------------------------------------------------------

BLUEPRINT_BOX="192.168.252.100"

HOST_CM_CMS=${HOST_CM_CMS:-${BLUEPRINT_BOX}}
HOST_CM_MLS=${HOST_CM_MLS:-${BLUEPRINT_BOX}}
HOST_CM_RLS=${HOST_CM_RLS:-${BLUEPRINT_BOX}}
HOST_CM_WFS=${HOST_CM_WFS:-${BLUEPRINT_BOX}}
HOST_DBA_CMS=${HOST_DBA_CMS:-${BLUEPRINT_BOX}}
HOST_DBA_MLS=${HOST_DBA_MLS:-${BLUEPRINT_BOX}}
HOST_DBA_RLS=${HOST_DBA_RLS:-${BLUEPRINT_BOX}}
HOST_CM_FEEDER_CONTENT=${HOST_CM_FEEDER_CONTENT:-${BLUEPRINT_BOX}}
HOST_CM_FEEDER_LIVE=${HOST_CM_FEEDER_LIVE:-${BLUEPRINT_BOX}}
HOST_CM_FEEDER_PREV=${HOST_CM_FEEDER_PREV:-${BLUEPRINT_BOX}}
HOST_CM_CAE_LIVE_1=${HOST_CM_CAE_LIVE_1:-${BLUEPRINT_BOX}}
HOST_CM_CAE_LIVE_2=${HOST_CM_CAE_LIVE_2:-${BLUEPRINT_BOX}}
HOST_CM_CAE_LIVE_3=${HOST_CM_CAE_LIVE_3:-${BLUEPRINT_BOX}}
HOST_CM_CAE_LIVE_4=${HOST_CM_CAE_LIVE_4:-${BLUEPRINT_BOX}}
HOST_CM_CAE_PREV=${HOST_CM_CAE_PREV:-${BLUEPRINT_BOX}}
HOST_CM_STUDIO=${HOST_CM_STUDIO:-${BLUEPRINT_BOX}}
HOST_CM_SOLR=${HOST_CM_SOLR:-${BLUEPRINT_BOX}}
HOST_CM_USERCHANGES=${HOST_CM_USERCHANGES:-${BLUEPRINT_BOX}}
HOST_CM_ELASTICWORKER=${HOST_CM_ELASTICWORKER:-${BLUEPRINT_BOX}}
HOST_CM_ADOBE_DRIVE=${HOST_CM_ADOBE_DRIVE:-${BLUEPRINT_BOX}}
HOST_CM_WEBDAV=${HOST_CM_WEBDAV:-${BLUEPRINT_BOX}}
HOST_CM_SITEMANAGER=${HOST_CM_SITEMANAGER:-${BLUEPRINT_BOX}}

# ---------------------------------------------------------------------------------------

JOLOKIA_IP=$(docker inspect --format '{{ .NetworkSettings.IPAddress }}' ${USER}-jolokia   2>/dev/null)
GRAPHITE_IP=$(docker inspect --format '{{ .NetworkSettings.IPAddress }}' ${USER}-graphite 2>/dev/null)
GRAFANA_IP=$(docker inspect --format '{{ .NetworkSettings.IPAddress }}' ${USER}-grafana   2>/dev/null)
ICINGA2_IP=$(docker inspect --format '{{ .NetworkSettings.IPAddress }}' ${USER}-icinga2   2>/dev/null)

net=$(docker inspect --format '{{ .HostConfig.NetworkMode }}' jolokia)

JOLOKIA_IP=$(docker inspect --format "{{ .NetworkSettings.Networks.${net}.IPAddress }}" jolokia   2>/dev/null)
GRAPHITE_IP=$(docker inspect --format "{{ .NetworkSettings.Networks.${net}.IPAddress }}" graphite 2>/dev/null)
GRAFANA_IP=$(docker inspect --format "{{ .NetworkSettings.Networks.${net}.IPAddress }}" grafana   2>/dev/null)
ICINGA2_IP=$(docker inspect --format "{{ .NetworkSettings.Networks.${net}.IPAddress }}" icinga2-core   2>/dev/null)

[ -z ${DOCKER_DATA_DIR} ] && { echo "Var DOCKER_DATA_DIR not set!"; exit 1; }

# ---------------------------------------------------------------------------------------

docker_opts=
docker_opts="${docker_opts} --interactive"
docker_opts="${docker_opts} --tty"
docker_opts="${docker_opts} --detach"
docker_opts="${docker_opts} --hostname=${USER}-${TYPE}"
docker_opts="${docker_opts} --name ${CONTAINER_NAME}"
docker_opts="${docker_opts} --volume /etc/localtime:/etc/localtime:ro"
docker_opts="${docker_opts} --volume ${PWD}/../docker-compose-monitoring/share/resolv.conf:/etc/resolv.conf:ro"
docker_opts="${docker_opts} --volume ${DOCKER_DATA_DIR}/monitoring:/var/cache/monitoring"
docker_opts="${docker_opts} --volume ${PWD}/inject/usr/local/sbin:/usr/local/sbin"
docker_opts="${docker_opts} --add-host=blueprint-box:${BLUEPRINT_BOX}"
docker_opts="${docker_opts} --net ${net}"

docker_opts="${docker_opts} --env HOST_CM_CMS=${HOST_CM_CMS}"
docker_opts="${docker_opts} --env HOST_CM_MLS=${HOST_CM_MLS}"
docker_opts="${docker_opts} --env HOST_CM_RLS=${HOST_CM_RLS}"
docker_opts="${docker_opts} --env HOST_CM_WFS=${HOST_CM_WFS}"
docker_opts="${docker_opts} --env HOST_DBA_CMS=${HOST_DBA_CMS}"
docker_opts="${docker_opts} --env HOST_DBA_MLS=${HOST_DBA_MLS}"
docker_opts="${docker_opts} --env HOST_DBA_RLS=${HOST_DBA_RLS}"
docker_opts="${docker_opts} --env HOST_CM_FEEDER_CONTENT=${HOST_CM_FEEDER_CONTENT}"
docker_opts="${docker_opts} --env HOST_CM_FEEDER_LIVE=${HOST_CM_FEEDER_LIVE}"
docker_opts="${docker_opts} --env HOST_CM_FEEDER_PREV=${HOST_CM_FEEDER_PREV}"
docker_opts="${docker_opts} --env HOST_CM_CAE_LIVE_1=${HOST_CM_CAE_LIVE_1}"
docker_opts="${docker_opts} --env HOST_CM_CAE_LIVE_2=${HOST_CM_CAE_LIVE_2}"
docker_opts="${docker_opts} --env HOST_CM_CAE_LIVE_3=${HOST_CM_CAE_LIVE_3}"
docker_opts="${docker_opts} --env HOST_CM_CAE_LIVE_4=${HOST_CM_CAE_LIVE_4}"
docker_opts="${docker_opts} --env HOST_CM_CAE_PREV=${HOST_CM_CAE_PREV}"
docker_opts="${docker_opts} --env HOST_CM_STUDIO=${HOST_CM_STUDIO}"
docker_opts="${docker_opts} --env HOST_CM_SOLR=${HOST_CM_SOLR}"
docker_opts="${docker_opts} --env HOST_CM_USERCHANGES=${HOST_CM_USERCHANGES}"
docker_opts="${docker_opts} --env HOST_CM_ELASTICWORKER=${HOST_CM_ELASTICWORKER}"
docker_opts="${docker_opts} --env HOST_CM_ADOBE_DRIVE=${HOST_CM_ADOBE_DRIVE}"
docker_opts="${docker_opts} --env HOST_CM_WEBDAV=${HOST_CM_WEBDAV}"
docker_opts="${docker_opts} --env HOST_CM_SITEMANAGER=${HOST_CM_SITEMANAGER}"

if [ ! -z ${ICINGA2_IP} ]
then
  docker_opts="${docker_opts} --env ICINGA2_HOST=${ICINGA2_IP}"
  docker_opts="${docker_opts} --env ICINGA2_API_PORT=${ICINGA2_API_PORT:-5665}"
  docker_opts="${docker_opts} --env ICINGA2_API_USER=${ICINGA2_API_USER:-root}"
  docker_opts="${docker_opts} --env ICINGA2_API_PASS=${ICINGA2_API_PASS:-icinga}"
#  docker_opts="${docker_opts} --link=icinga2-core:icinga"
fi

if [ ! -z ${GRAPHITE_IP} ]
then
  docker_opts="${docker_opts} --env GRAPHITE_HOST=${GRAPHITE_IP}"
  docker_opts="${docker_opts} --env GRAPHITE_PORT=${GRAPHITE_PORT}"
#  docker_opts="${docker_opts} --link=graphite:graphite"
fi

if [ ! -z ${GRAFANA_IP} ]
then
  docker_opts="${docker_opts} --env GRAFANA_HOST=${GRAFANA_IP}"
  docker_opts="${docker_opts} --env GRAFANA_PORT=3000"
#  docker_opts="${docker_opts} --link=grafana:grafana"
fi

if [ ! -z ${JOLOKIA_IP} ]
then
  docker_opts="${docker_opts} --env JOLOKIA_HOST=${JOLOKIA_IP}"
#  docker_opts="${docker_opts} --link=jolokia:jolokia"
fi

if [ ! -z ${DOCKER_DNS} ]
then
  docker_opts="${docker_opts} --dns=${DOCKER_DNS}"
fi

# ---------------------------------------------------------------------------------------

docker run \
  ${docker_opts} \
  ${TAG_NAME} \
  /bin/bash

# ---------------------------------------------------------------------------------------
# EOF
