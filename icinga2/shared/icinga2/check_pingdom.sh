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

PINGDOM_CREDENTIALS="engineering-tools@coremedia.com:F9i3vzl8WDl6cqTxDVb8cYUoAJ1RJyR2uAgwrW3L"

API_KEY="v9gp3wp9qrqzxip0buv8fbm8plu88iwk"

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
#      mode=${m}
      mode="$(cat ${TMP_FILE} | jq -c '.checks[] | select( .status | contains ('\"${m}\"') )' | wc -l)"
      msg="${msg} ${mode} Hosts with Status '${m}' "
    done

    msg="OK  ${msg}"
    result=${STATE_OK}


  else
    msg="UNKNOWN  No Hosts with 'up', 'down' or 'paused' Status found!"
    result=${STATE_UNKNOWN}
  fi


  echo ${msg}
  exit ${result}
}

# --------------------------------------------------------------------------------------------------------




# curl --user $PINGDOM_CREDENTIALS --request POST --data name=$NAME-studio --data type=http --data host=studio.helios.$NAME.cloud.perfect-chef.com --data encryption=true --data port=443 --header "App-Key: v9gp3wp9qrqzxip0buv8fbm8plu88iwk" https://api.pingdom.com/api/2.0/checks


#curl --silent --user ${PINGDOM_CREDENTIALS} --header "App-Key: ${API_KEY}" --header 'Content-Type: application/json'  https://api.pingdom.com/api/2.0/checks | python -mjson.tool | jq -c '.checks[] | select( .status | contains ("up") )'
#curl --silent --user ${PINGDOM_CREDENTIALS} --header "App-Key: ${API_KEY}" --header 'Content-Type: application/json'  https://api.pingdom.com/api/2.0/checks | python -mjson.tool | jq -c '.checks[] | select( .status | contains ("paused") )'

foo() {
# Parse parameters
while [ $# -gt 0 ]
do
  case "${1}" in
    -h|--help) shift
      usage;
      exit 0
      ;;
    -v|--version) shift
      version;
      exit 0
      ;;
    -H|--host)
      shift
      HOST="${1}"
      ;;
    -j|--job)
      shift
      JOB="${1}"
      ;;
    -l|--joblist)
      shift
      JOBLIST="${1}"
      ;;
    *)
      echo "Unknown argument: '${1}'"
      exit $STATE_UNKNOWN
      ;;
  esac
shift
done

# Check that required argument (metric) was specified
[ -z "${HOST}" ] && {
  echo "Usage error: 'host' parameter missing"
  usage
  exit ${STATE_UNKNOWN}
}

( [ -z "${JOB}" ] && [ -z "${JOBLIST}" ] ) && {
  echo "Usage error: 'job' or 'joblist' parameter missing"
  usage
  exit ${STATE_UNKNOWN}
}

}

#----------------------------------------------------------------------------------------

run


exit 0

# EOF
