#!/bin/bash

# set -x

SRC_BASE=${PWD}

for d in docker-mysql docker-jolokia docker-graphite docker-icinga2 docker-icingaweb2 docker-grafana docker-dashing
do
  if [ -x ${SRC_BASE}/${d}/run.sh ]
  then
    cd ${SRC_BASE}/${d}

    echo " => starting Container '${d}' ..."    

    ./run.sh > /dev/null
  else
    echo "no run.sh found"
  fi

  echo -e "\n =========================================================== \n"
done

# EOF
