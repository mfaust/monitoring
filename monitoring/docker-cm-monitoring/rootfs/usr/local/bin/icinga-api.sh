#!/bin/bash

set -e
# set -x

ICINGA2_HOST=${ICINGA2_HOST:-localhost}

FILTER=

ICINGA_JSON_PATH="/usr/local/icinga2"

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
  printf  "$help_format_desc"  ""    "-h"   ": Show this help"
  printf  "$help_format_desc"  ""    "-v"   ": Prints out the Version"

}

# --------------------------------------------------------------------------------------------------------------------

run() {

  API_USER="root"
  API_PASS="icinga"
  curl_opts="-u ${API_USER}:${API_PASS} -k -s "

  for f in $(ls -1 ${ICINGA_JSON_PATH}/hosts/${FILTER}*.json)
  do
    host=$(basename ${f} | sed 's|\.json||g')

    if [ $(curl ${curl_opts} -H 'Accept: application/json' -X GET "https://${ICINGA2_HOST}:5665/v1/objects/hosts/${host}" | python -mjson.tool | jq --raw-output '.status' | grep "No objects found" | wc -l) -eq 1 ]
    then
      echo -n "add Host '${host}'   "
      curl --silent ${curl_opts} -H 'Accept: application/json' -X PUT "https://${ICINGA2_HOST}:5665/v1/objects/hosts/${host}" --data @${f} | python -mjson.tool
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
    *)
      echo "Unknown argument: $1"
      exit 2
      ;;
  esac
shift
done

# ----------------------------------------------------------------------------------------

run

exit 0
