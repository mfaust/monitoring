#!/bin/bash

TMP_DIR="/tmp"
JOLOKIA_PORT_CACHE="${TMP_DIR}/MONITOR_JOLOKIA.tmp"
MAX_CACHE_TIME=4

CRIT=2
WARN=1

DAEMON=false

STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3
STATE_DEPENDENT=4

# Wie oft wird der Check durch den Daemon aufgerufen
INTERVAL=58

BLUEPRINT_BOX=${BLUEPRINT_BOX:-""}

if [ -z ${BLUEPRINT_BOX} ]
then
  echo "UNKNOWN - No Blueprint Box given!"

  exit ${STATE_UNKNOWN}
fi

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
  printf  "$help_format_desc"  ""    "-h"   ": Show this help"
  printf  "$help_format_desc"  ""    "-v"   ": Prints out the Version"

}

# --------------------------------------------------------------------------------------------------------------------

getPorts() {

  PORTS="$(${NMAP} ${BLUEPRINT_BOX} -p T:38099,40099,41099,42099,43099,44099,45099,46099,47099,48099,49099 | grep "tcp open" | cut -d / -f 1)"

  echo "PORTS=\"${PORTS}\"" > ${JOLOKIA_PORT_CACHE}
}




# ----------------------------------------------------------------------------------------

buildChecks() {

  for p in ${PORTS}
  do
    jmx=JMX_${p}

    for c in ${!jmx}
    do
      file_tpl="${TEMPLATE_DIR}/${c}.json.tpl"

      dir="${TMP_DIR}/${p}"
      [ -d ${dir} ] || mkdir -p ${dir}

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

        if ( [ ${c} = "SolrReplicationHandler" ] && ( [ ${p} -eq 44099 ] || [ ${p} -eq 45099 ] ) )
        then
          :
#           for s in live preview studio
#           do
#             file_dst_solr="${dir}/${c}.${s}.json"
#
#             if [ -f ${file_dst_solr} ]
#             then
#               continue
#             fi
#
#             cp ${file_tpl} ${file_dst_solr}
#
#             sed -i "s/%SHARD%/${s}/g" ${file_dst_solr}
#             sed -i "s/%PORT%/${p}/g"  ${file_dst_solr}
#
#           done
        else
          if [ -f ${file_dst} ]
          then
            continue
          fi

          sed -e "s/localhost:%PORT%/${BLUEPRINT_BOX}:${p}/g" ${file_tpl} > ${file_dst}
        fi
      fi

    done
  done
}

runChecks() {

  for p in ${PORTS}
  do

    dir="${TMP_DIR}/${p}"
    if [ ! -d ${dir} ]
    then
      buildChecks
    fi

    for i in $(ls -1 ${dir}/*.json)
    do
      dst="$(echo ${i} | sed 's/\.json/\.result/g')"
      tmp="$(echo ${i} | sed 's/\.json/\.tmp/g')"

      touch ${tmp}

      ionice -c2 nice -n19  curl --silent --request POST --data @${i} http://jolokia:8080/jolokia/ | json_reformat > ${tmp}
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

  if [ $(fping -r1 ${BLUEPRINT_BOX} | grep "is alive" | wc -l) -gt 0 ]
  then
    if [ $(nmap jolokia -p 8080  | grep -c "tcp open") -lt 0 ]
    then
      echo "no jolokia tomcat running"

      [ -f ${TMP_DIR}/jolokia-check.run ] && rm -f ${TMP_DIR}/jolokia-check.run

      exit 2
    fi

    if [ ! -f ${JOLOKIA_PORT_CACHE} ]
    then
      echo "no ports cache '${JOLOKIA_PORT_CACHE}' found"
      getPorts
    else
      filemtime=$(stat -c %Y ${JOLOKIA_PORT_CACHE})
      currtime=$(date +%s)
      diff=$(( (currtime - filemtime) / 30 ))

      if [ ${diff} -gt 30 ]
      then
        echo "port cache is older than 30 minutes"

        getPorts
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
      while sleep "${INTERVAL}"
      do
        runChecks
      done
    else
      runChecks
    fi


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
    -D|--daemon)
      DAEMON=true
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
