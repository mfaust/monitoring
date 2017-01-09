#!/bin/sh

set -e

GRAPHITE_HOST=${GRAPHITE_HOST:-graphite}
GRAPHITE_PORT=${GRAPHITE_PORT:-2003}

MEMCACHE_HOST=${MEMCACHE_HOST:-''}
MEMCACHE_PORT=${MEMCACHE_PORT:-11211}

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

run() {

  createConfig

  /usr/sbin/collectd -C ${cfgFile} -f
}

run

#EOF
