#!/bin/bash

set -e

sudo docker run \
  --tty=false \
  --interactive=false \
  --dns=10.1.2.14 \
  --dns=10.1.2.63 \
  --publish=80:80 \
  --publish=5665:5665 \
  --volume=${PWD}/shared/icinga2:/usr/local/share/icinga2 \
  --name icinga2 \
  --hostname=docker-icinga2-${USER}.coremedia.vm \
  ${USER}-icinga2

# EOF

