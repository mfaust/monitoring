#!/bin/bash

# set -x

SRC_BASE=${PWD}

for d in $(find ${SRC_BASE} -mindepth 1 -maxdepth 1 -type d | sort)
do
  if [ -x ${d}/build.sh ]
  then
    cd ${d}
    echo " => build Container '${d}' ..."

     ./build.sh
  fi

  echo -e "\n =========================================================== \n"
done

# EOF
