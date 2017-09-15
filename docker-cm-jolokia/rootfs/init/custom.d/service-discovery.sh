#!/bin/sh

set -e
set -x

if [ -e /usr/bin/service-discovery ]
then
  echo "start service discovery rest service ..."

  exec /usr/bin/service-discovery &
fi
