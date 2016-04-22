#!/bin/bash
#
# part of CoreMedia Monitoring
#
# Watch CM7 Licenses

export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8

CMS_PATH="$(find /opt -type d  -name cm7-cms-tools)"
CMS_TOOL="${CMS_PATH}/bin/cm"

MLS_PATH="$(find /opt -type d  -name cm7-mls-tools)"
MLS_TOOL="${MLS_PATH}/bin/cm"

RLS_PATH="$(find /opt -type d  -name cm7-rls-tools)"
RLS_TOOL="${RLS_PATH}/bin/cm"

TMP_DIR="/var/tmp"
TMP_FILE="cm7_watch-users.tmp"

STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3
STATE_DEPENDENT=4

TMP_DIR="/var/cache/monitor"

[ -d ${TMP_DIR} ] || mkdir -p "${TMP_DIR}"

WARN=50
CRIT=15

# ----------------------------------------------------------------------------------------

CMS_LICENSE_CACHE="${TMP_DIR}/cms-license.cache"
CMS_LICENSE_MD5="${TMP_DIR}/cms-license.md5"
CMS_LICENCE_FILE="$(find /opt/coremedia/cm7-cms-tomcat -type f -name license.zip)"

MLS_LICENSE_CACHE="${TMP_DIR}/mls-license.cache"
MLS_LICENSE_MD5="${TMP_DIR}/mls-license.md5"
MLS_LICENCE_FILE="$(find /opt/coremedia/cm7-mls-tomcat -type f -name license.zip)"

RLS_LICENSE_CACHE="${TMP_DIR}/rls-license.cache"
RLS_LICENSE_MD5="${TMP_DIR}/rls-license.md5"
RLS_LICENCE_FILE="$(find /opt/coremedia/cm7-rls-tomcat -type f -name license.zip)"

CMS_LICENSE=
MLS_LICENSE=
RLS_LICENSE=

# ----------------------------------------------------------------------------------------

buildCache() {

  local app="${1}"
  local LICENSE_CACHE="${TMP_DIR}/${app}-license.cache"
  local LICENSE_MD5="${TMP_DIR}/${app}-license.md5"
  local LICENCE_FILE=

  local CM_TOOL=

  case ${app} in
    cms)  CM_TOOL=${CMS_TOOL} ; LICENCE_FILE=${CMS_LICENCE_FILE} ;;
    mls)  CM_TOOL=${MLS_TOOL} ; LICENCE_FILE=${MLS_LICENCE_FILE} ;;
    rls)  CM_TOOL=${RLS_TOOL} ; LICENCE_FILE=${RLS_LICENCE_FILE} ;;
    *)
      echo "no valid contentservice"
      return
  esac

  if [ "${CM_TOOL}" == "/bin/cm" ]
  then
    echo "missing installed cm tools for contentserver '${app}'"
    return
  fi

  export JAVA_HOME=/usr/java/latest

  if [ ! -f ${LICENSE_MD5} ]
  then
    md5sum ${LICENCE_FILE} | cut -c 1-32 > ${LICENSE_MD5}
  else
    MD5="$(cat ${LICENSE_MD5})"
    FILE="$(md5sum ${LICENCE_FILE} | cut -c 1-32)"

    # pruefen, ob eine neue Lizenzdatei vorliegt
    if [ "${MD5}" != "${FILE}" ]
    then
      rm -f ${LICENSE_MD5}
      rm -f ${LICENSE_CACHE}

      md5sum ${LICENCE_FILE} | cut -c 1-32 > ${LICENSE_MD5}
    fi
  fi

  if [ ! -f ${LICENSE_CACHE} ]
  then
    ${CM_TOOL} license -u webserver -p webserver > ${LICENSE_CACHE}
  fi

  if [ ! -f ${LICENSE_CACHE} ]
  then
    return
  fi

  FROM="$(cat ${LICENSE_CACHE}  | grep 'valid from'  | awk '{print $3}' | awk -F'T' '{print $1}' )" # 2015-07-15T02:00:00+02:00
  UNTIL="$(cat ${LICENSE_CACHE} | grep 'valid until' | awk '{print $3}' | awk -F'T' '{print $1}' )"
  GRACE="$(cat ${LICENSE_CACHE} | grep 'grace until' | awk '{print $3}' | awk -F'T' '{print $1}' )"

  if [ -z ${UNTIL} ]
  then
    echo "CRITICAL - CM License has no valid License-Date"

    rm -f ${LICENSE_MD5}
    rm -f ${LICENSE_CACHE}

    return
  fi

  DEADLINE="$(expr '(' $(date -d ${UNTIL} +%s) - $(date +%s) + 86399 ')' / 86400)"

  FROM="$(date +%d.%m.%Y --date="${FROM}")"   # 2015-07-15T02:00:00+02:00 -> 15.07.2015
  UNTIL="$(date +%d.%m.%Y --date="${UNTIL}")"
  GRACE="$(date +%d.%m.%Y --date="${GRACE}")"

  printf_opts="\"%s\": { \"%s\": \"%s\", \"%s\": \"%s\", \"%s\": \"%s\", \"%s\": %d },"

  printf "${printf_opts}" \
    ${app} \
    "valid_from" ${FROM} \
    "valid_until" ${UNTIL} \
    "valid_grace" ${GRACE} \
    "deadline" ${DEADLINE} \
    > ${TMP_DIR}/${app}-license.tmp

}

buildJson() {

  for a in cms mls rls
  do
    if [ -f ${TMP_DIR}/${a}-license.tmp ]
    then
      cat ${TMP_DIR}/${a}-license.tmp >> ${TMP_DIR}/license.tmp
    fi
  done

  # entferne das letzte zeichen
  r=$(cat ${TMP_DIR}/license.tmp)
  r=$(echo "${r%?}")

  echo "{ $r }" | json_reformat > ${TMP_DIR}/cm-licenses.result

}


run() {

  for a in cms mls rls
  do
    buildCache "${a}"
  done

  buildJson

  rm -fv ${TMP_DIR}/*license.tmp
}


run

exit 0

# EOF