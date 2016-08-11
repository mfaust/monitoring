#!/bin/bash

# -------------------------------------------------------------------------------------------------

# trap ctrl-c and call ctrl_c()
trap ctrl_c SIGHUP SIGINT SIGTERM

function ctrl_c() {
  echo "** Trapped CTRL-C"

  exit 0
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

  startSupervisor

  cat /etc/motd

#  eval /bin/bash

  while true
  do
    sleep 5m
    # echo -n "."
  done
}

run

#EOF
