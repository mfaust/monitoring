#!/bin/bash

set -e
# set -x

GRAPHITE_HOST=${GRAPHITE_HOST:-graphite}
GRAPHITE_PORT=${GRAPHITE_PORT:-2003}

MEMCACHE_HOST=${MEMCACHE_HOST:-''}
MEMCACHE_PORT=${MEMCACHE_PORT:-11211}

SUPPORT_EXTERNAL_DISCOVERY=${SUPPORT_EXTERNAL_DISCOVERY:-false}

# -------------------------------------------------------------------------------------------------

# trap ctrl-c and call ctrl_c()
trap ctrl_c SIGHUP SIGINT SIGTERM

function ctrl_c() {
  echo "** Trapped CTRL-C"

  exit 0
}

cfgFile="/etc/collectd/collectd.conf"

createConfig() {

  sed -i \
    -e "s/%GRAPHITE_HOST%/${GRAPHITE_HOST}/" \
    -e "s/%GRAPHITE_PORT%/${GRAPHITE_PORT}/" \
    ${cfgFile}
}

externalDiscovery() {

  if ( [ ${SUPPORT_EXTERNAL_DISCOVERY} = true ] && [ -f /etc/supervisor.d/external-discover.ini ] )
  then
    rm -f /etc/supervisor.d/external-discover.ini
  fi

}

startSupervisor() {

  echo -e "\n Starting Supervisor.\n\n"

  if [ -f /etc/supervisord.conf ]
  then
    /usr/bin/supervisord -c /etc/supervisord.conf >> /dev/null
  else
    exec /bin/sh
  fi
}

run() {

  externalDiscovery

  createConfig

  startSupervisor

#   cat /etc/motd

#   while true
#   do
#     sleep 5m
    # echo -n "."
#   done
}

run

#EOF
