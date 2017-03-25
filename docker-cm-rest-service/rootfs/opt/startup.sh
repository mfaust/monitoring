#!/bin/sh

set -e

# -------------------------------------------------------------------------------------------------

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

  /usr/local/bin/rest-service.rb
}

run

#EOF
