#!/bin/bash
#
#
# version 2



# ----------------------------------------------------------------------------------------

SCRIPTNAME=$(basename $0 .sh)
VERSION="2.20.0"
VDATE="24.03.2016"

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
  printf  "$help_format_title" "run checks against jolokia to get json results from JMX"
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
  printf  "$help_format_desc"  ""    "-i|--interval"      ": in daemon Mode, you cant set the runtime intervall in seconds (default: 58sec)"
#  printf  "$help_format_desc"  ""    "-f|--force"         ": regeneration Port-Cache every 30 Minutes (default: no force)"
#  printf  "$help_format_desc"  ""    "-H|--host"          ": Hostname or IP (default: Environment Variable CHECK_HOST)"
#  printf  "$help_format_desc"  ""    "-P|--old-portstyle" ": old port style for service discovery"
}

# --------------------------------------------------------------------------------------------------------------------

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

  . ${TMP_DIR}/cm-services

  for p in ${PORTS}
  do

    dir="${TMP_DIR}/${p}"
    if [ ! -d ${dir} ]
    then
      echo "build Checks .. ${dir}"
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

worker() {

  for host in $(find ${JOLOKIA_CACHE_BASE} -type d -mindepth 1 -maxdepth 1 -exec basename {} \;)
  do

    echo " => ${host}"

    TMP_DIR="${JOLOKIA_CACHE_BASE}/${host}"
    JOLOKIA_PORT_CACHE="${JOLOKIA_CACHE_BASE}/${host}/PORT.cache"
    HOST_ALIVE="${JOLOKIA_CACHE_BASE}/${host}/alive"

    if [ -f ${HOST_ALIVE} ]
    then

      . ${JOLOKIA_PORT_CACHE}

      if [ $(echo "${PORTS}" | wc -w) -eq 0 ]
      then
        echo " [E] no valid ports found"
        echo "     skip ..."
        continue
      fi

      runChecks ${host}

    else
      echo " [E] host '${host}' is not alive"
    fi
  done
}

run() {

  checkJolokia

  if [ ${JOLOKIA_AVAILABLE} == false ]
  then
    echo " [W] needed jolokia service are not available"
    echo "     skip checks ..."
  else

    if [ ${DAEMON} = true ]
    then
      while true
      do
        worker

        sleep "${RUN_INTERVAL}"
      done
    else
      worker
    fi

  fi
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
    -D|--daemon)
      DAEMON=true
      ;;
    -i|--interval)
      shift
      RUN_INTERVAL="${1}"
      ;;
    *)
      echo "Unknown argument: '${1}'"
      exit 2
      ;;
  esac
shift
done

# ----------------------------------------------------------------------------------------

run

exit 0
