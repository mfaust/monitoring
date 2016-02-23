#!/bin/bash

TMP_DIR="/tmp"
TMP_FILE="${TMP_DIR}/MONITOR_PINGDOM_DATA.tmp"
MAX_CACHE_TIME=4

CRIT=2
WARN=1

STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3
STATE_DEPENDENT=4

#export LC_ALL=en_US.UTF-8
#export LANG=en_US.UTF-8

PINGDOM_USER=${PINGDOM_USER:-""}
PINGDOM_PASS=${PINGDOM_PASS:-""}
PINGDOM_API=${PINGDOM_API:-""}

if ( [ -z ${PINGDOM_USER} ] || [ -z ${PINGDOM_PASS} ] || [ -z ${PINGDOM_API} ] )
then
  echo "UNKNOWN - No Pingdom Credentials available!"

  exit ${STATE_UNKNOWN}
fi

# --------------------------------------------------------------------------------------------------------

PINGDOM_CREDENTIALS="${PINGDOM_USER}:${PINGDOM_PASS}"
API_KEY="${PINGDOM_API}"

# --------------------------------------------------------------------------------------------------------

buildCache() {

  curl --silent --user ${PINGDOM_CREDENTIALS} --header "App-Key: ${API_KEY}" https://api.pingdom.com/api/2.0/checks | python -mjson.tool > ${TMP_FILE}
}

# --------------------------------------------------------------------------------------------------------

run() {

  if [ -f "${TMP_FILE}" ]
  then
    filemtime=$(stat -c %Y ${TMP_FILE})
    currtime=$(date +%s)
#    diff=$(( (currtime - filemtime) / 86400 ))
    diff=$(( (currtime - filemtime) / 30 ))
    diff=$( echo "(${currtime} - ${filemtime}) / 30" | bc )
#    echo " .. ${filemtime} / ${currtime} : ${diff}"

    if ( [ ${diff} -gt ${MAX_CACHE_TIME} ] || [ ${diff} -eq ${MAX_CACHE_TIME} ] )
    then
      rm -f ${TMP_FILE}
    fi
  fi

  if [ ! -f "${TMP_FILE}" ]
  then
    buildCache
  fi

  msg=

  count=$(cat ${TMP_FILE} | jq -c '.checks[] | .status' | wc -l)

  if [ ${count} -gt 0 ]
  then

    for m in up down paused
    do
      mode="$(cat ${TMP_FILE} | jq -c '.checks[] | select( .status | contains ('\"${m}\"') )' | wc -l)"

      case ${m} in
        "down")      status="CRITICAL"  ;;
        *)           status="OKAY"      ;;
      esac

      if [ ${mode} -gt 0 ]
      then
        msg="${msg} ${mode} Hosts with Status '${m}' (${status}) "
      fi
    done

    countOKAY=$(echo "${msg}" | grep "OKAY" | wc -l )
    countCRITICAL=$(echo "${msg}" | grep "CRITICAL" | wc -l )
    countUNKNOWN=$(echo "${msg}" | grep "unknown" | wc -l )

    if [ ${countCRITICAL} -gt 0 ]
    then
      status="CRITICAL"
      result=${STATE_CRITICAL}
    elif [ ${countUNKNOWN} -gt 0 ]
    then
      status="WARNING"
      result=${STATE_WARNING}
    else
      status="OK"
      result=${STATE_OK}
    fi

    msg="${status}  ${msg}"
#    result=${STATE_OK}

  else
    msg="UNKNOWN  No Hosts with 'up', 'down' or 'paused' Status found!"
    result=${STATE_UNKNOWN}
  fi

  echo "${msg}"
  exit ${result}
}

# --------------------------------------------------------------------------------------------------------

run

exit 0

# EOF
