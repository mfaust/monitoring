#!/bin/bash

set -e
# set -x

# GRAPHITE_HOST=${GRAPHITE_HOST:-graphite}
# GRAPHITE_PORT=${GRAPHITE_PORT:-2003}

# MEMCACHE_HOST=${MEMCACHE_HOST:-''}
# MEMCACHE_PORT=${MEMCACHE_PORT:-11211}

# -------------------------------------------------------------------------------------------------

# trap ctrl-c and call ctrl_c()
# trap ctrl_c SIGHUP SIGINT SIGTERM
#
# function ctrl_c() {
#   echo "** Trapped CTRL-C"
#
#   exit 0
# }

# cfgFile="/etc/collectd/collectd.conf"
#
# createConfig() {
#
#   sed -i \
#     -e "s/%GRAPHITE_HOST%/${GRAPHITE_HOST}/" \
#     -e "s/%GRAPHITE_PORT%/${GRAPHITE_PORT}/" \
#     ${cfgFile}
# }
#
# startSupervisor() {
#
#   echo -e "\n Starting Supervisor.\n\n"
#
#   if [ -f /etc/supervisord.conf ]
#   then
#     /usr/bin/supervisord -c /etc/supervisord.conf >> /dev/null
#   else
#     exec /bin/sh
#   fi
# }

addDNS() {

  if [ ! -z "${BLUEPRINT_BOX}" ]
  then

    while ! nc -z dnsdock 80
    do
      echo -n " ."
      sleep 5s
    done
    echo " "

    sleep 5s

    curl \
      http://dnsdock/services/blueprint-box \
      --silent \
      --request PUT \
      --data-ascii "{\"name\":\"blueprint-box\",\"image\":\"blueprint-box\",\"ips\":[${BLUEPRINT_BOX}],\"ttl\":0}"

  fi
}

run() {

  addDNS

#   createConfig

  /usr/local/bin/rest-service.rb

#  startSupervisor
}

run

#EOF
