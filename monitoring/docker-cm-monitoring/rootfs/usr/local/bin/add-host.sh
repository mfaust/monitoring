#!/bin/bash
#
#
#

# ----------------------------------------------------------------------------------------

SCRIPTNAME=$(basename $0 .sh)
VERSION="2.1.1"
VDATE="24.05.2016"

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

    # known-ports ... for pre 16xx and current deployment
    scan_ports="3306,28017,38099,40099,40199,40299,40399,40499,40599,40699,40799,40899,40999,41099,41199,41299,41399,42099,42199,42299,42399,42499,42599,42699,42799,42899,42999,43099,44099,45099,46099,47099,48099,49099"

    PORTS="$(${NMAP} ${host} -p T:${scan_ports} | grep "tcp open" | cut -d / -f 1)"
  fi

  echo "PORTS=\"${PORTS}\"" > ${JOLOKIA_PORT_CACHE}
}

discoverApplications() {

  local tmp_dir="${1}"
  local p="${2}"

  types="manager blueprint drive solr user-changes workflow webdav elastic-worker coremedia contentfeeder caefeeder studio editor-webstart demodata-generator"

  for t in ${types}
  do
#    echo "${p} ${t}"

    file_dst="${tmp_dir}/CM_${p}-${t}.json"
    dst="${tmp_dir}/CM_${p}.result"
    tmp="${tmp_dir}/CM_${p}-${t}.tmp"

    cp ${file_tpl} ${file_dst}

    sed -i \
      -e "s/%HOST%/${host}/g" \
      -e "s/%PORT%/${p}/g" \
      -e "s/%TYPE%/${t}/g" \
      ${file_dst}

    touch ${tmp}

    ionice -c2 nice -n19  curl --silent --request POST --data @${file_dst} http://${JOLOKIA_HOST}:8080/jolokia/ | json_reformat > ${tmp}

    [ $(stat -c %s ${tmp}) -gt 0 ] && {

      status="$(jq --raw-output .status ${tmp})"

      if [ ${status} == 200 ]
      then
#        echo "status 200 - take ${t}"
        mv ${tmp} ${dst}
        rm -f ${file_dst}
#        sleep 3s
        return

      else
        rm ${tmp}
        rm ${file_dst}
      fi
    } || {
      rm -f ${tmp}
    }
  done

}


discoverPorts() {

  local host="${1}"

  local file_tpl=
  local file_dst=

  getPorts ${host}

  if [ -f ${JOLOKIA_PORT_CACHE} ]
  then
    . ${JOLOKIA_PORT_CACHE}

    for p in ${PORTS}
    do
      if [ ${p} == 3306 ]
      then
        echo " Port: ${p}  | service: mysql"
      elif [ ${p} == 28017 ]
      then
        echo " Port: ${p}  | service: mongod"
      else

        file_tpl="${TEMPLATE_DIR}/jolokia/CM.json.tpl"

        tmp_dir="/tmp/${host}"

        [ -d ${tmp_dir} ] || mkdir -p ${tmp_dir}

        if [ -f ${file_tpl} ]
        then
          discoverApplications ${tmp_dir} ${p}
        fi
      fi

    done

    service_tmp_file="${tmp_dir}/cm-services.tmp"

    touch ${service_tmp_file}

    for f in $(ls -1 ${tmp_dir}/CM_*.result)
    do
#       echo -e "\n - analyze '${f}'"

      port=$(echo ${f} | sed -e "s|${tmp_dir}/CM_||g" -e 's|.result||g' )

      baseName=$(jq --raw-output .value.baseName ${f})
      path=$(jq --raw-output .value.path ${f})

      configFile=$(jq --raw-output .value.configFile.url ${f})

      if ( [ "${baseName}" == "manager" ] || [ "${baseName}" == "coremedia" ] )
      then
        service="$(echo ${configFile} | awk -F'/' '{ print( $4 ) }' | sed -e 's|cm7-||g' -e 's|-tomcat||g')"
      else
        service="${baseName}"

        cat >> ${tmp_dir}/CM_${port}_context.json << EOF
{
  "type" : "read",
  "mbean" : "Catalina:type=Manager,context=${path},host=localhost",
  "attribute" : [
    "jvmRoute"
  ],
  "target" : { "url" : "service:jmx:rmi:///jndi/rmi://${host}:${port}/jmxrmi", }
}
EOF
        ionice -c2 nice -n19  curl --silent --request POST --data @${tmp_dir}/CM_${port}_context.json http://${JOLOKIA_HOST}:8080/jolokia/ | json_reformat > ${tmp_dir}/CM_${port}_context.tmp

        service="$(jq --raw-output .value.jvmRoute ${tmp_dir}/CM_${port}_context.tmp)"

      fi

      # service name normalize
      case ${service} in
        content-management-server)        service='cms' ;;
        master-live-server)               service='mls' ;;
        workflow|workflow-server)         service='wfs' ;;
        replication-live-server)          service='rls' ;;
        adobe-drive-server)               service='adobe-drive' ;;
        solr-master|solr-slave)           service='solr' ;;
        delivery|cae-live-*)              service='cae-live' ;;
        # content-feeder | user-changes | elastic-worker
        *)                                service=${service} ;;
      esac

      echo "Port: ${port}  | service: ${service}"

      if [ -f ${TEMPLATE_DIR}/cm-services/${service}.tpl ]
      then

        cp ${TEMPLATE_DIR}/cm-services/${service}.tpl ${tmp_dir}
        sed -i -e "s/%PORT%/${port}/g" ${tmp_dir}/${service}.tpl

        cat ${tmp_dir}/${service}.tpl >> ${service_tmp_file}
      fi

    done

    cp ${service_tmp_file} ${TMP_DIR}/cm-services
  fi

}

# TODO:
# split dashboard in services - see above
addToGraphite() {

  local host="${1}"
  local tpl_dir="${TEMPLATE_DIR}/grafana"
  local curl_opts="--silent --user admin:admin"

  if [ ${FORCE} != true ]
  then
#    echo "delete dashboard for host '${host}'"

    short_hostname=$(echo "${host}" | awk -F '.' '{print($1)}')
    grafana_hostname=$(echo "${host}" | sed 's|\.|-|g')

    data="$(curl ${curl_opts} -X GET "http://grafana:3000/api/search?query=&tag=${short_hostname}")"

    uid=$(echo "${data}" | jq --raw-output '.[].uri')

    for i in ${uid}
    do

#      echo "delete dashboard '${i}'"
      curl ${curl_opts} -X DELETE http://grafana:3000/api/dashboards/${i} > /dev/null
    done
  fi

  echo "add grafana templates ..."
  for tpl in $(ls -1 ${tpl_dir}/blueprint*.json)
  do
    # "title": "Blueprint ContentServer",

    [ -d /var/tmp/${short_hostname} ] || mkdir /var/tmp/${short_hostname}

#    cp  ${tpl_dir}/${tpl} /var/tmp/${short_hostname}/${tpl}
    cp  ${tpl} /var/tmp/${short_hostname}/$(basename ${tpl})

    sed -i \
      -e "s|%HOST%|${grafana_hostname}|g" \
      -e "s|%SHORTHOST%|${short_hostname}|g" \
      -e "s|%TAG%|${short_hostname}|g" \
      /var/tmp/${short_hostname}/$(basename ${tpl})

    echo "create dashboard '$(basename ${tpl})'"

      curl ${curl_opts} \
        --request POST \
        --header 'Content-Type: application/json;charset=UTF-8' \
        --data @/var/tmp/${short_hostname}/$(basename ${tpl}) \
        http://grafana:3000/api/dashboards/db/ > /dev/null
  done

}


addIcingaService() {

  local name="${1}"
  local template="${2}"
  local curl_opts="-u ${ICINGA2_API_USER}:${ICINGA2_API_PASS} -k -s "

  local url=$(printf 'https://%s:%s/v1/objects/services/%s!%s' ${ICINGA2_HOST} ${ICINGA2_API_PORT} "${host}" "${name}")

  curl ${curl_opts} -v -H 'Accept: application/json' -X PUT ${url} --data @${TMP_DIR}/icinga2/${template}

}

addToIcinga() {

  if [ -z ${ICINGA2_HOST} ]
  then
    echo "no icinga2 host configured ... skip"
    return
  fi

  local host="${1}"
  local tpl_dir="${TEMPLATE_DIR}/icinga2"
  local ip=$(host ${host} | cut -d ' ' -f 4)
  local apps="cms mls rls wfs adobe_drive cae_live cae_prev elastic_worker feeder_content feeder_live feeder_prev site_manager solr studio user_changes webdav"
  local services=$(grep '='  ${TMP_DIR}/cm-services  | grep -v standardJMX | sort)
  local vars=

  local curl_opts="-u ${ICINGA2_API_USER}:${ICINGA2_API_PASS} -k -s "

  mkdir -p ${TMP_DIR}/icinga2

  name=$(curl ${curl_opts} -H 'Accept: application/json' -X GET "https://${ICINGA2_HOST}:${ICINGA2_API_PORT}/v1/objects/hosts/${host}" | python -m json.tool | jq --raw-output '.results[0].attrs.name')

  if ( [ "${name}" == "${host}" ] && [ ${ICINGA2_REMOVE_HOST} == true ] )
  then
    echo "delete Host '${host}'"

    curl ${curl_opts} \
     -H 'Accept: application/json' \
     -H 'X-HTTP-Method-Override: DELETE' \
     -X POST \
     "https://${ICINGA2_HOST}:${ICINGA2_API_PORT}/v1/objects/hosts/${host}?cascade=1" | python -m json.tool

    ICINGA2_REMOVE_HOST=
    name=

    sleep 2s
  fi

  for k in ${apps}
  do
    value=$( [ $(echo "${services}" | tr '[:upper:]' '[:lower:]' | grep -c ${k}) -gt 0 ] && { echo "true"; } || { echo "false"; } )
    vars="${vars} ${k}=${value}"
  done

  tpl=$(jo -p templates[]="generic-host" attrs=$(jo  display_name=${host} address=${ip} vars=$(jo ${vars}) ))

  echo "${tpl}" > ${TMP_DIR}/icinga2/host.json

  if ( [ -z ${name} ] || [ "${name}" == "null" ] )
  then
    echo -n "add Host '${host}'   "
    curl ${curl_opts} -H 'Accept: application/json' -X PUT "https://${ICINGA2_HOST}:${ICINGA2_API_PORT}/v1/objects/hosts/${host}" --data @${TMP_DIR}/icinga2/host.json | python -mjson.tool > /dev/null
    echo ".. done"
  else
    echo "Host ${host} already monitored"
  fi

  echo "add Services for Host '${host}'"
  for k in ${apps}
  do
    service=$(echo "${services}" | grep -i ${k} | cut -d '=' -f 1)
    port=$(echo "${services}" | grep -i ${k} | cut -d '=' -f 2 | sed 's|99|80|g')

    if [ $(jq ".attrs.vars.${k}" ${TMP_DIR}/icinga2/host.json) == true ]
    then
      case ${k} in
        cms)

          attrs="$(jo display_name="Check IOR against CMS" check_command=http host_name=${host} max_check_attempts=5 vars.http_port=${port} vars.http_uri=/coremedia/ior vars.http_string=IOR:)"
          jo -p templates[]="generic-service" attrs="${attrs}" > ${TMP_DIR}/icinga2/service-ior-${k}.json

          addIcingaService "check-cm-ior-2-${k}" service-ior-${k}.json

          attrs="$(jo display_name="Check IOR against CMS" check_command=http host_name=${host} max_check_attempts=5 vars.http_port=${port} vars.http_uri=/coremedia/ior vars.http_string=IOR:)"

          ;;
        mls)
          attrs="$(jo display_name="Check IOR against MLS" check_command=http host_name=${host} max_check_attempts=5 vars.http_port=${port} vars.http_uri=/coremedia/ior vars.http_string=IOR:)"
          jo -p templates[]="generic-service" attrs="${attrs}" > ${TMP_DIR}/icinga2/service-ior-${k}.json

          addIcingaService "check-cm-ior-2-${k}" service-ior-${k}.json
          ;;
        rls)
          attrs="$(jo display_name="Check IOR against RLS" check_command=http host_name=${host} max_check_attempts=5 vars.http_port=${port} vars.http_uri=/coremedia/ior vars.http_string=IOR:)"
          jo -p templates[]="generic-service" attrs="${attrs}" > ${TMP_DIR}/icinga2/service-ior-${k}.json

          addIcingaService "check-cm-ior-2-${k}" service-ior-${k}.json
          ;;
        feeder_content)
          attrs="$(jo display_name="Content Feeder" check_command=cm_feeder host_name=${host} max_check_attempts=5 vars.host=${host} vars.feeder=content)"
          jo -p templates[]="generic-service" attrs="${attrs}" > ${TMP_DIR}/icinga2/service-${k}.json

          addIcingaService "check-cm-feeder-content" service-${k}.json

          ;;
        feeder_live)
          attrs="$(jo display_name="CAE Live Feeder" check_command=cm_feeder host_name=${host} max_check_attempts=5 vars.host=${host} vars.feeder=live)"
          jo -p templates[]="generic-service" attrs="${attrs}" > ${TMP_DIR}/icinga2/service-${k}.json

          addIcingaService "check-cm-feeder-live" service-${k}.json
          ;;
        feeder_prev)
          attrs="$(jo display_name="CAE Preview Feeder" check_command=cm_feeder host_name=${host} max_check_attempts=5 vars.host=${host} vars.feeder=preview)"
          jo -p templates[]="generic-service" attrs="${attrs}" > ${TMP_DIR}/icinga2/service-${k}.json

          addIcingaService "check-cm-feeder-prev" service-${k}.json
          ;;

      esac
    fi

  done





#  return





  # URL
  # url=$(printf 'https://%s:%s/v1/objects/services/%s!%s' $ICINGA2_HOST $ICINGA2_API_PORT "co7madv01.coremedia.com" "check-cm-ior-2-mls")

  # Service Check
  # attrs="$(jo display_name="Check IOR against MLS" check_command=check_http host_name=co7madv01.coremedia.com max_check_attempts=5 vars.http_port=30280 vars.http_uri=/coremedia/ior vars.http_string=IOR:)"
  # jo -p templates[]="generic-service" attrs="${attrs}" > /tmp/icinga2-service.json

  # jo -p templates[]="generic-service" attrs=$(jo name=check-cm-ior-2-mls check_command=nrpe host_name=172.17.0.9 max_check_attempts=5 check_interval=5m retry_interval=45s vars=$(jo nrpe_command=check_ior nrpe_arguments[]=co7madv01.coremedia.com nrpe_arguments[]=40280) ) > /root/icinga-service_2.json

  # LIST
  # curl ${curl_opts} -H 'Accept: application/json' 'https://172.17.0.5:5665/v1/objects/hosts' | python -m json.tool
  # curl ${curl_opts} -H 'Accept: application/json' 'https://172.17.0.5:5665/v1/objects/services' | python -m json.tool

  # DELETE Service
  # curl ${curl_opts} -H 'Accept: application/json' -H 'X-HTTP-Method-Override: DELETE' -X POST -k "https://${ICINGA2_HOST}:5665/v1/objects/services/co7madv01.coremedia.com!check-cm-ior-2-mls" | python -m json.tool

  # ADD Service
  # curl ${curl_opts} -v -H 'Accept: application/json' -X PUT 'https://172.17.0.5:5665/v1/objects/services/co7madv01.coremedia.com!check-cm-ior-2-mls' --data @/root/icinga-service_2.json | python -m json.tool
}


run() {

  echo -e "\n\n"

  TMP_DIR="${JOLOKIA_CACHE_BASE}/${CHECK_HOST}"

  if [ ${FORCE} = true ]
  then
    [ -d ${TMP_DIR} ] && rm -rf ${TMP_DIR}

    ICINGA2_REMOVE_HOST=true
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
        discoverPorts ${CHECK_HOST}

        addToGraphite ${CHECK_HOST}

        addToIcinga ${CHECK_HOST}

        supervisorctl restart all
      fi
    fi
  fi

  rm -rf /tmp/${CHECK_HOST}

  echo -e "\n"
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

