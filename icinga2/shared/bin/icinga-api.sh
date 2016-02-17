#!/bin/bash

set -e
# set -x

API_USER="root"
API_PASS="icinga"
curl_opts="-u ${API_USER}:${API_PASS} -k -s "

run() {

  for f in $(ls -1 ${PWD}/shared/json/hosts/*.json)
  do
    host=$(basename ${f} | sed 's|\.json||g')

    if [ $(curl ${curl_opts} -H 'Accept: application/json' -X GET "https://localhost:5665/v1/objects/hosts/${host}" | python -mjson.tool | jq --raw-output '.status' | grep "No objects found" | wc -l) -eq 1 ]
    then
      echo -n "add Host '${host}'   "
      curl --silent ${curl_opts} -H 'Accept: application/json' -X PUT "https://localhost:5665/v1/objects/hosts/${host}" --data @${f}
      echo ".. done"
    else
      echo "Host ${host} already monitored"
    fi
  done
}

run

exit 0
