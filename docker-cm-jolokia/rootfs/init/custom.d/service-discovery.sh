#!/bin/sh

unset  http_proxy
unset  https_proxy
unset  HTTP_PROXY_AUTH


set -e

if [ -e /usr/bin/service-discovery ]
then
  echo "start service discovery rest service ..."

  exec /usr/bin/service-discovery &
fi
