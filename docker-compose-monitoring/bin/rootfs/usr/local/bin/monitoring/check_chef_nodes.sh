#!/bin/bash

FQDN=
IP=
ONLINE=
OFFLINE=

TMP_DIR="/tmp"
TMP_FILE="${TMP_DIR}/MONITOR_UNHEALTY_NODES.tmp"
MAX_CACHE_TIME=4

CRIT=2
WARN=1

STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3
STATE_DEPENDENT=4

# export LC_ALL=en_US.UTF-8
# export LANG=en_US.UTF-8

getFQDN() {

  local host="${1}"

  fqdn=$(host -4 -t A ${host})

  if [ $(echo "${fqdn}" | grep -c "Host ${host} not found") -eq 0 ]
  then
    FQDN=$(echo "${fqdn}" | awk -F ' has address ' '{print($1)}')
    IP=$(echo "${fqdn}"| awk -F ' has address ' '{printf($2)}')
  else
    FQDN="${host}"
    IP="No DNS Record"
  fi
}

# --------------------------------------------------------------------------------------------------------

getUnhealthyFromChef() {

  UNHEALTY_NODES=$(knife status --hide-healthy --long | grep -v presales | sort -g > ${TMP_FILE})
}

addTo() {

  local type="${1}"
  local host="${2}"

  if [ ${type} = "online" ]
  then
    ONLINE="${ONLINE},${host}"
  else
    OFFLINE="${OFFLINE},${host}"
  fi
}

mping() {

  # state=$(ping -c1 ${1} | grep icmp | grep bytes | wc -l)

  # ONLINE Nodes are registerd in the chef-Server, but they last chef-client run is long time ago
  # ONLINE Nodes are still in production and must be monitored

  # OFFLINE Nodes are registerd in the chef-Server, but they are offline or otherwise not available
  # OFFLINE Nodes can be ignored, but they would be displayed

  result=$(fping -r1 ${1})
  countOn=$(echo -e "${result}" | grep "is alive" | wc -l)
  countOff=$(echo -e "${result}" | grep "is unreachable" | wc -l)
}


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
    getUnhealthyFromChef
  fi

  UNHEALTY_COUNT=$(wc -l ${TMP_FILE} | awk '{printf($1)}')

  if [ ${UNHEALTY_COUNT} -gt 0 ]
  then

    while IFS=',' read LAST NAME FQDN IP junk
    do
      command="${command} ${IP}"
    done < ${TMP_FILE}

    mping "${command}"

    state_msg="${countOn} Nodes are online, but no chef-client run ; ${countOff} Nodes are offline or otherwise not available"

    if [ ${countOn} -gt ${CRIT} ]
    then
      echo "CRITICAL - ${state_msg}"
      result=${STATE_CRITICAL}
    elif ( [ ${countOn} -gt ${WARN} ] || [ ${countOn} -eq ${WARN} ] )
    then
      echo "WARNING - ${state_msg}"
      result=${STATE_WARNING}
    else
      echo "OK - ${state_msg}"
      result=${STATE_OK}
    fi

  else
    echo "CRITICAL - No Check Results"
    result=${STATE_CRITICAL}
  fi

  exit ${result}
}

run


exit 0