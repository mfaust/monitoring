#!/bin/bash

set -e
set -x

FILTER=
ADDRESS=
NAME=

PRG=$(readlink -f ${0})
BIN=$(dirname "${PRG}")

# ----------------------------------------------------------------------------------------

version() {

  help_format_title="%-9s %s\n"

  echo ""
  printf  "$help_format_title" "jolokia Checks and Results"
  echo ""
  printf  "$help_format_title" " Version $VERSION ($VDATE)"
  echo ""
}

usage() {

  help_format_title="%-9s %s\n"
  help_format_desc="%-9s %-10s %s\n"
  help_format_example="%-9s %-30s %s\n"

  version

  printf  "$help_format_title" "Usage:"    "$SCRIPTNAME [-h] [-v]"
  printf  "$help_format_desc"  ""    "-h"         ": Show this help"
  printf  "$help_format_desc"  ""    "-v"         ": Prints out the Version"
  printf  "$help_format_desc"  ""    "--filter"   ": add Filter to add hosts"
  printf  "$help_format_desc"  ""    "--address"  ": [optional] overwrite Hostname"
  printf  "$help_format_desc"  ""    "--name"     ": [optional] overwrite Description"

}

# --------------------------------------------------------------------------------------------------------------------

run() {

  API_USER="root"
  API_PASS="icinga"
  curl_opts="-u ${API_USER}:${API_PASS} -k -s "

  for f in $(ls -1 $(readlink -f ${BIN}/../json/hosts/${FILTER}*.json))
  do
    host=$(basename ${f} | sed 's|\.json||g')

    if [ $(grep -c "%ADDRESS%" ${f}) -eq 1 ]
    then
      echo "found template file."
      if ( [ -z ${ADDRESS} ] || [ -z ${NAME} ] )
      then
        echo "need --address AND --name entry .."
        exit 2
      else
        cp ${f} /tmp/${ADDRESS}.json
        sed -i "s|%ADDRESS%|${ADDRESS}|g" /tmp/${ADDRESS}.json
        sed -i "s|%NAME%|${NAME}|g" /tmp/${ADDRESS}.json

        host=${NAME}
        f=/tmp/${ADDRESS}.json

      fi

    fi

    status_1=$(curl ${curl_opts} -H 'Accept: application/json' -X GET "https://localhost:5665/v1/objects/hosts/${host}" | python -mjson.tool | jq --raw-output '.status' | grep "No objects found" | wc -l)
    status_2=$(curl ${curl_opts} -H 'Accept: application/json' -X GET "https://localhost:5665/v1/objects/hosts?name=${host}" | python -mjson.tool | jq --raw-output '.status')     

    if [ ${status_1} -eq 1 ]
    then
      echo -n "add Host '${host}'   "
      curl --silent ${curl_opts} -H 'Accept: application/json' -X PUT "https://localhost:5665/v1/objects/hosts/${host}" --data @${f} | python -mjson.tool
      echo ".. done"
    elif [ "${status_2}" == 'null' ]
    then
      echo -n "add Host '${host}'   "
      curl --silent ${curl_opts} -H 'Accept: application/json' -X PUT "https://localhost:5665/v1/objects/hosts/${host}" --data @${f} | python -mjson.tool
      echo ".. done"
    else
      echo "Host ${host} already monitored"
    fi
  done
}

# ----------------------------------------------------------------------------------------

# Parse parameters
while [ $# -gt 0 ]
do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    -v|--version)
      version
      exit 0
      ;;
    -f|--filter)
      shift
      FILTER="${1}"
      ;;
    --address)
      shift
      ADDRESS="${1}"
      ;;
    --name)
      shift
      NAME="${1}"
      ;;
    *)  echo "Unknown argument: $1"
      exit $STATE_UNKNOWN
      ;;
  esac
shift
done

# ----------------------------------------------------------------------------------------

run

exit 0

# to add a service-check

# curl ${curl_opts} -H 'Accept: application/json' -X PUT 'https://localhost:5665/v1/objects/services/blueprint.box!check_pingdom' --data @json/services/check_pingdom.json | python -mjson.tool