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

rights() {

  chgrp nobody /var/log
  chmod g+w /var/log
  
  touch /var/log/collectd.log
  chmod a+w /var/log/collectd.log
  chown nobody:nobody /var/log/collectd.log
}

startSupervisor() {

#  echo -e "\n Starting Supervisor.\n\n"

  if [ -f /etc/supervisord.conf ]
  then
    /usr/bin/supervisord -c /etc/supervisord.conf >> /dev/null
  else
    exec /bin/sh
  fi
}

run() {

  createConfig

  rights

  startSupervisor

#  /usr/sbin/collectd -C ${cfgFile} -f
}

run

#EOF
