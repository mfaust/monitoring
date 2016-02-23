#!/bin/bash

set -e

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

sudo docker run \
  --tty=false \
  --interactive=false \
  --dns=10.1.2.14 \
  --dns=10.1.2.63 \
  --publish=80:80 \
  --publish=5665:5665 \
  --detach=true \
  --volume=${PWD}/shared/icinga2:/usr/local/share/icinga2 \
  --name icinga2 \
  --hostname=${USER}-icinga2.coremedia.vm \
  --add-host blueprint.box:192.168.252.100 \
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
  --link=jolokia:${USER}-jolokia \
  ${USER}-docker-icinga2


sleep 10s

./shared/bin/icinga-api.sh --filter "blueprint"

# EOF



# docker run --tty=false --interactive=false --dns=10.1.2.14 --publish=80:80 --publish=5665:5665 --detach=true --volume=${PWD}/shared/icinga2:/usr/local/share/icinga2 --name icinga2 --hostname=${USER}-icinga.coremedia.vm
# --env PINGDOM_USER=engineering-tools@coremedia.com --env PINGDOM_PASS=F9i3vzl8WDl6cqTxDVb8cYUoAJ1RJyR2uAgwrW3L --env PINGDOM_API=v9gp3wp9qrqzxip0buv8fbm8plu88iwk
# --env BLUEPRINT_BOX=192.168.252.100
# --add-host blueprint.box:192.168.252.100
# --link=jolokia:jolokia-${USER} bodsch-icinga2
# 0b9d8737f180a31a5041431125bc4528c8ce20d5af52850f1f5b22ec6bb517f4
