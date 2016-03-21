#!/bin/bash
#
#
# version 2

# ----------------------------------------------------------------------------------------

SCRIPTNAME=$(basename $0 .sh)
VERSION="2.10.0"
VDATE="21.03.2016"

# ----------------------------------------------------------------------------------------

TMP_DIR="/tmp"

JOLOKIA_PORT_CACHE=
JOLOKIA_HOST=${JOLOKIA_HOST:-}
JOLOKIA_AVAILABLE=false

# Wie oft wird der Check durch den Daemon aufgerufen
RUN_INTERVAL=${RUN_INTERVAL:-58}

CRIT=2
WARN=1

DAEMON=false
FORCE=false

STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3
STATE_DEPENDENT=4

CHECK_HOST=
PORT_STYLE="cm14"

env | grep BLUEPRINT  > /etc/env.vars
env | grep HOST_     >> /etc/env.vars

NMAP=$(which nmap)

if [ -z ${NMAP} ]
then
  echo "UNKNOWN - No nmap installed!"

  exit ${STATE_UNKNOWN}
fi

. /etc/jolokia.rc

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
  printf  "$help_format_desc"  ""    "-h"                 ": Show this help"
  printf  "$help_format_desc"  ""    "-v"                 ": Prints out the Version"
  printf  "$help_format_desc"  ""    "-D|--daemon"        ": start in Daemon-Mode (default: no daemon)"
  printf  "$help_format_desc"  ""    "-f|--force"         ": regeneration Port-Cache every 30 Minutes (default: no force)"
  printf  "$help_format_desc"  ""    "-H|--host"          ": Hostname or IP (default: Environment Variable CHECK_HOST)"
  printf  "$help_format_desc"  ""    "-P|--old-portstyle" ": old port style for service discovery"
}

# --------------------------------------------------------------------------------------------------------------------

getPorts() {

  local host="${1}"
  local PORTS=
  local scan_ports=""

  if [ $(fping -r1 ${host} | grep "is alive" | wc -l) -gt 0 ]
  then

    if [ "${PORT_STYLE}" == "cm7" ]
    then
      # CM7-Port
      scan_ports="38099,40099,41099,42099,43099,44099,45099,46099,47099,48099,49099"
#      PORTS="$(${NMAP} ${BLUEPRINT_BOX} -p T:38099,40099,41099,42099,43099,44099,45099,46099,47099,48099,49099 | grep "tcp open" | cut -d / -f 1)"
    else
      # CMx-Port (new Deployment-schema)
      scan_ports="40099,40199,40299,40399,40499,40599,40699,40799,40899,40999,41099,41199,41299,41399,42099,42199,42299,42399,42499,42599,42699,42799,42899,42999"
    fi

    PORTS="$(${NMAP} ${host} -p T:${scan_ports} | grep "tcp open" | cut -d / -f 1)"
  fi

  echo "PORTS=\"${PORTS}\"" > ${JOLOKIA_PORT_CACHE}
}

checkJolokia() {

  if [ -z ${JOLOKIA_HOST} ]
  then
    JOLOKIA_AVAILABLE=false
    return
  fi

  if [ $(fping -r1 ${JOLOKIA_HOST} | grep "is alive" | wc -l) -gt 0 ]
  then

    if [ $(nmap ${JOLOKIA_HOST} -p 8080 | grep -A1 PORT | grep -c "8080/tcp open") -eq 0 ]
    then
      echo "no jolokia tomcat running"
      JOLOKIA_AVAILABLE=false

      [ -f ${TMP_DIR}/jolokia-check.run ] && rm -f ${TMP_DIR}/jolokia-check.run
    else
      JOLOKIA_AVAILABLE=true
    fi
  else
    JOLOKIA_AVAILABLE=false
  fi
}

# ----------------------------------------------------------------------------------------

buildChecks() {

  local host="${1}"

  for p in ${PORTS}
  do
    jmx=JMX_${p}

    for c in ${!jmx}
    do
      file_tpl="${TEMPLATE_DIR}/${c}.json.tpl"

      dir="${TMP_DIR}/${p}"

      [ -d ${dir} ] || mkdir -vp ${dir}

      file_dst="${dir}/${c}.json"

      if [ -f "${file_dst}" ]
      then
        filemtime=$(stat -c %Y ${file_dst})
        currtime=$(date +%s)
        diff=$(( (currtime - filemtime) / 86400 ))
        if [ ${diff} -gt ${MAX_JSON_TIME} ]
        then
          rm -f ${file_dst}
        fi
      fi

      if [ -f "${file_tpl}" ]
      then

        # old
        #if ( [ ${c} = "SolrReplicationHandler" ] && ( [ ${p} -eq 44099 ] || [ ${p} -eq 45099 ] ) )
        # new
        if ( [ ${c} = "SolrReplicationHandler" ] && [ ${p} -eq 40099 ] )
        then

          for s in live preview studio
          do
            file_dst_solr="${dir}/${c}.${s}.json"

            if [ -f ${file_dst_solr} ]
            then
              continue
            fi

            cp ${file_tpl} ${file_dst_solr}

            sed -i \
              -e "s/%SHARD%/${s}/g" \
              -e "s/localhost:%PORT%/${host}:${p}/g" \
              ${file_dst_solr}

          done
        else
          if [ -f ${file_dst} ]
          then
            continue
          fi

          sed -e "s/localhost:%PORT%/${host}:${p}/g" ${file_tpl} > ${file_dst}
        fi
      fi

    done
  done
}

runChecks() {

  local host="${1}"

  for p in ${PORTS}
  do

    dir="${TMP_DIR}/${p}"
    if [ ! -d ${dir} ]
    then
      echo "build Checks .."
      buildChecks ${host}
    fi

    for i in $(ls -1 ${dir}/*.json 2> /dev/null)
    do
      dst="$(echo ${i} | sed 's/\.json/\.result/g')"
      tmp="$(echo ${i} | sed 's/\.json/\.tmp/g')"

      touch ${tmp}

      ionice -c2 nice -n19  curl --silent --request POST --data @${i} http://${JOLOKIA_HOST}:8080/jolokia/ | json_reformat > ${tmp}
#      sleep 1s

      [ $(stat -c %s ${tmp}) -gt 0 ] && {
        mv ${tmp} ${dst}
      } || {
        rm -f ${tmp}
      }
    done

#     if ( [ ${p} -eq 44099 ] || [ ${p} -eq 45099 ] )
#     then
#       port="$(echo ${p} | sed 's|99|80|g')"
#       for s in live preview studio
#       do
#         dst="${dir}/solr.${s}.result"
#         tmp="${dir}/solr.${s}.tmp"
#
#         touch ${tmp}
#
#         ionice -c2 nice -n19  curl --silent --request GET "http://jolokia:${port}/solr/${s}/replication?command=details&wt=json" | json_reformat > ${tmp}
#         sleep 1s
#
#         [ $(stat -c %s ${tmp}) -gt 0 ] && {
#           mv ${tmp} ${dst}
#         } || {
#           rm -f ${tmp}
#         }
#       done
#     fi

  done

  touch ${TMP_DIR}/jolokia-check.run
}

# ----------------------------------------------------------------------------------------

run() {

  checkJolokia

  if [ ${JOLOKIA_AVAILABLE} == false ]
  then
    echo "needed jolokia service are not available"
    echo "skip checks ..."
  else

    if [ -z ${CHECK_HOST} ]
    then
      if [ -f /etc/env.vars ]
      then

        . /etc/env.vars

        while read line
        do
  #        echo $line
          host=$(echo ${line} | awk -F'=' '{print ( $1 ) }')

          CHECK_HOST="${CHECK_HOST} ${host}"
        done < /etc/env.vars
      fi
    else
      export BLUEPRINT_BOX=${CHECK_HOST}
      CHECK_HOST="BLUEPRINT_BOX"
    fi


    for host in ${CHECK_HOST}
    do
#       echo "${host} == ${!host}"

      if [ $(fping -r1 ${!host} | grep "is alive" | wc -l) -gt 0 ]
      then
        echo "host '${host}' is alive"

        TMP_DIR="${JOLOKIA_CACHE_BASE}/${!host}"

        [ -d ${TMP_DIR} ] || mkdir -p ${TMP_DIR}

        JOLOKIA_PORT_CACHE="${TMP_DIR}/MONITOR_JOLOKIA.tmp"

        if [ ! -f ${JOLOKIA_PORT_CACHE} ]
        then
          echo "no ports cache '${JOLOKIA_PORT_CACHE}' found"
          getPorts ${!host}
        else

          if [ ${FORCE} = force ]
          then
            filemtime=$(stat -c %Y ${JOLOKIA_PORT_CACHE})
            currtime=$(date +%s)
            diff=$(( (currtime - filemtime) / 30 ))

            if [ ${diff} -gt 30 ]
            then
              echo "port cache is older than 30 minutes"

              getPorts ${!host}
            fi
          fi
        fi

        . ${JOLOKIA_PORT_CACHE}

        if [ $(echo "${PORTS}" | wc -w) -eq 0 ]
        then
          echo "no valid ports found"

          exit 2
        fi

        if [ ${DAEMON} = true ]
        then
          while true
          do
            runChecks ${!host}

            sleep "${RUN_INTERVAL}"
          done
        else
          runChecks ${!host}
        fi

      else
        echo "host '${host}' is not alive"
      fi

    done
  fi

}



# ----------------------------------------------------------------------------------------

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
    -H|--HOST)
      shift
      CHECK_HOST="${1}"
      ;;
    -D|--daemon)
      DAEMON=true
      ;;
    -f|--force)
      FORCE=true
      ;;
    -P|--old-portstyle)
      PORT_STYLE="cm7"
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
