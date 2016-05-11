#!/bin/bash
#
#
#

# ----------------------------------------------------------------------------------------

SCRIPTNAME=$(basename $0 .sh)
VERSION="1.0.0"
VDATE="24.03.2016"

# ----------------------------------------------------------------------------------------

TMP_DIR=

FORCE=false
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
  printf  "$help_format_title" "scan Ports on Host for Application Monitoring"
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
  printf  "$help_format_desc"  ""    "-f|--force"         ": regeneration all Host-Data (default: no force)"
  printf  "$help_format_desc"  ""    "-H|--host"          ": Hostname or IP"
  printf  "$help_format_desc"  ""    "-P|--old-portstyle" ": old port style for service discovery"
}

# --------------------------------------------------------------------------------------------------------------------

checkHostAlive() {

  local host="${1}"
  local alive=false

  HOST_ALIVE="${TMP_DIR}/alive"

  if [ ! -f ${HOST_ALIVE} ]
  then
    if [ $(fping -r1 ${host} | grep "is alive" | wc -l) -gt 0 ]
    then
      touch ${HOST_ALIVE}
      alive=true
    else
      alive=false
    fi
  else
    filemtime=$(stat -c %Y ${HOST_ALIVE})
    currtime=$(date +%s)
    diff=$(( (currtime - filemtime) / 86400 ))
    if [ ${diff} -gt 1 ]
    then
      rm -f ${HOST_ALIVE}

      checkHostAlive
    else
      alive=true
    fi
  fi

  echo $alive
}


getPorts() {

  local host="${1}"
  local PORTS=
  local scan_ports=

  if [ $(fping -r1 ${host} | grep "is alive" | wc -l) -gt 0 ]
  then

    if [ "${PORT_STYLE}" == "cm7" ]
    then
      # CM7-Port
      scan_ports="38099,40099,41099,42099,43099,44099,45099,46099,47099,48099,49099"

      cp /etc/cm7-services ${TMP_DIR}/cm-services
    else
      # CMx-Port (new Deployment-schema)
      scan_ports="40099,40199,40299,40399,40499,40599,40699,40799,40899,40999,41099,41199,41299,41399,42099,42199,42299,42399,42499,42599,42699,42799,42899,42999"

      cp /etc/cm14-services ${TMP_DIR}/cm-services
    fi

    PORTS="$(${NMAP} ${host} -p T:${scan_ports} | grep "tcp open" | cut -d / -f 1)"
  fi

  echo "PORTS=\"${PORTS}\"" > ${JOLOKIA_PORT_CACHE}
}

verifyApplications() {

  local host="${1}"

  local file_tpl=
  local file_dst=

  if [ -f ${JOLOKIA_PORT_CACHE} ]
  then
    . ${JOLOKIA_PORT_CACHE}

    for p in ${PORTS}
    do
      file_tpl="${TEMPLATE_DIR}/CM.json.tpl"
      file_dst="/tmp/CM_${p}.json"

      if [ -f ${file_tpl} ]
      then
        sed -e "s/localhost:%PORT%/${host}:${p}/g" ${file_tpl} > ${file_dst}

        dst="$(echo ${file_dst} | sed 's/\.json/\.result/g')"
        tmp="$(echo ${file_dst} | sed 's/\.json/\.tmp/g')"

        touch ${tmp}

        ionice -c2 nice -n19  curl --silent --request POST --data @${file_dst} http://${JOLOKIA_HOST}:8080/jolokia/ | json_reformat > ${tmp}

        [ $(stat -c %s ${tmp}) -gt 0 ] && {
          mv ${tmp} ${dst}
        } || {
          rm -f ${tmp}
        }
      fi
    done

    service_tmp_file="/tmp/cm-services.tmp"

    touch ${service_tmp_file}

    for f in $(ls -1 /tmp/CM_*.result)
    do
      port=$(echo ${f} | sed -e 's|/tmp/CM_||g' -e 's|.result||g' )
      service="$(jq --raw-output .value.configFile.url ${f} | awk -F'/' '{ print( $4 ) }' | sed -e 's|cm7-||g' -e 's|-tomcat||g')"

      echo "Port: ${port}  | service: ${service}"

      cp /etc/cm-services/${service}.tpl /tmp
      sed -i -e "s/%PORT%/${port}/g" /tmp/${service}.tpl

      cat /tmp/${service}.tpl >> ${service_tmp_file}

      rm -f /tmp/${service}.tpl
    done

    cp ${service_tmp_file} ${TMP_DIR}/cm-services
  fi

}

# TODO:
# split dashboard in services - see above
addToGraphite() {

  local host="${1}"
  local tpl_dir="/usr/local/share/grafana/dashboards"
  local curl_opts="--silent --user admin:admin"

  if [ ${FORCE} != true ]
  then
    echo "delete dashboard for host '${host}'"

    short_hostname=$(echo "${host}" | awk -F '.' '{print($1)}')
    grafana_hostname=$(echo "${host}" | sed 's|\.|-|g')

    data="$(curl ${curl_opts} -X GET "http://grafana:3000/api/search?query=&tag=${short_hostname}")"

    uid=$(echo "${data}" | jq --raw-output '.[].uri')

    for i in ${uid}
    do

      echo "delete dashboard '${i}'"
      curl ${curl_opts} -X DELETE http://grafana:3000/api/dashboards/${i} > /dev/null
    done
  fi

  echo "add grafana templates ..."
  for tpl in $(ls -1 ${tpl_dir})
  do
    # "title": "Blueprint ContentServer",

    [ -d /var/tmp/${short_hostname} ] || mkdir /var/tmp/${short_hostname}

    cp  ${tpl_dir}/${tpl} /var/tmp/${short_hostname}/${tpl}

    sed -i \
      -e "s|%HOST%|${grafana_hostname}|g" \
      -e "s|%SHORTHOST%|${short_hostname}|g" \
      -e "s|%TAG%|${short_hostname}|g" \
      /var/tmp/${short_hostname}/${tpl}

    echo "create dashboard '${tpl}'"

      curl ${curl_opts} \
        --request POST \
        --header 'Content-Type: application/json;charset=UTF-8' \
        --data @/var/tmp/${short_hostname}/${tpl} \
        http://grafana:3000/api/dashboards/db/ > /dev/null
  done

}



run() {

  TMP_DIR="${JOLOKIA_CACHE_BASE}/${CHECK_HOST}"

  if [ ${FORCE} = true ]
  then
    [ -d ${TMP_DIR} ] && rm -rf ${TMP_DIR}

    # for DAEMON Mode
    FORCE=false
  fi

  [ -d ${TMP_DIR} ] || mkdir -p ${TMP_DIR}

  JOLOKIA_PORT_CACHE="${TMP_DIR}/PORT.cache"
  HOST_ALIVE="${TMP_DIR}/alive"

  alive=$(checkHostAlive ${CHECK_HOST})

  if [ ${alive} == true ]
  then
    if [ -d ${JOLOKIA_CACHE_BASE}/${CHECK_HOST} ]
    then
      if [ ! -f ${JOLOKIA_PORT_CACHE} ]
      then
        getPorts ${CHECK_HOST}

        verifyApplications ${CHECK_HOST}

        addToGraphite ${CHECK_HOST}

        supervisorctl restart all
      fi
    fi
  fi

  rm -f /tmp/CM_*99*
  rm -f /tmp/cm-services.tmp
}

# --------------------------------------------------------------------------------------------------------------------

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
    -H|--host)
      shift
      CHECK_HOST="${1}"
      ;;
    -f|--force)
      FORCE=true
      ;;
    -P|--old-portstyle)
      PORT_STYLE="cm7"
      ;;
    *)
      echo "Unknown argument: '${1}'"
      exit 2
      ;;
  esac
shift
done

# --------------------------------------------------------------------------------------------------------------------

run

exit 0
# EOF

