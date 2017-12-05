#!/bin/sh

export WORK_DIR=/srv

# -------------------------------------------------------------------------------------------------

extract_vars() {

  if [ ! -z "${ICINGA_CERT_SERVICE}" ]
  then

#     echo "${ICINGA_CERT_SERVICE}" | json_verify -q 2> /dev/null
#
#     if [ $? -gt 0 ]
#     then
#       echo " [E] the ICINGA_CERT_SERVICE Environment ist not an json"
#       exit 1
#     fi
#
#     if ( [ "${ICINGA_CERT_SERVICE}" == "true" ] || [ "${ICINGA_CERT_SERVICE}" == "true" ] )
#     then
#       echo " [E] the ICINGA_CERT_SERVICE Environment must be an json, not true or false!"
#       exit 1
#     fi

    ICINGA_CERT_SERVICE_SERVER=$(echo "${ICINGA_CERT_SERVICE}" | jq --raw-output .server)
    ICINGA_CERT_SERVICE_PORT=$(echo "${ICINGA_CERT_SERVICE}" | jq --raw-output .port)
    ICINGA_CERT_SERVICE_PATH=$(echo "${ICINGA_CERT_SERVICE}" | jq --raw-output .path)
    ICINGA_CERT_SERVICE_API_USER=$(echo "${ICINGA_CERT_SERVICE}" | jq --raw-output .api.user)
    ICINGA_CERT_SERVICE_API_PASSWORD=$(echo "${ICINGA_CERT_SERVICE}" | jq --raw-output .api.password)
    ICINGA_CERT_SERVICE_BA_USER=$(echo "${ICINGA_CERT_SERVICE}" | jq --raw-output .ba.user)
    ICINGA_CERT_SERVICE_BA_PASSWORD=$(echo "${ICINGA_CERT_SERVICE}" | jq --raw-output .ba.password)

    [ "${ICINGA_CERT_SERVICE_SERVER}" == null ] && ICINGA_CERT_SERVICE_SERVER=
    [ "${ICINGA_CERT_SERVICE_PORT}" == null ] && ICINGA_CERT_SERVICE_PORT=4567
    [ "${ICINGA_CERT_SERVICE_PATH}" == null ] && ICINGA_CERT_SERVICE_PATH="/"
    [ "${ICINGA_CERT_SERVICE_API_USER}" == null ] && ICINGA_CERT_SERVICE_API_USER=
    [ "${ICINGA_CERT_SERVICE_API_PASSWORD}" == null ] && ICINGA_CERT_SERVICE_API_PASSWORD=
    [ "${ICINGA_CERT_SERVICE_BA_USER}" == null ] && ICINGA_CERT_SERVICE_BA_USER=
    [ "${ICINGA_CERT_SERVICE_BA_PASSWORD}" == null ] && ICINGA_CERT_SERVICE_BA_PASSWORD=

    if (
      [ ! -z ${ICINGA_CERT_SERVICE_SERVER} ] &&
      [ ! -z ${ICINGA_CERT_SERVICE_PORT} ] &&
      [ ! -z ${ICINGA_CERT_SERVICE_BA_USER} ] &&
      [ ! -z ${ICINGA_CERT_SERVICE_BA_PASSWORD} ] &&
      [ ! -z ${ICINGA_CERT_SERVICE_API_USER} ] &&
      [ ! -z ${ICINGA_CERT_SERVICE_API_PASSWORD} ]
    )
    then
      USE_CERT_SERVICE="true"
    fi
  fi
}

extract_vars

. /init/wait_for/cert_service.sh
. /init/icinga_cert.sh

if [ -d ${WORK_DIR}/pki/${HOSTNAME} ]
then
  echo " [i] export PKI vars"

  export ICINGA_API_PKI_PATH=${WORK_DIR}/pki/${HOSTNAME}
  export ICINGA_API_NODE_NAME=${HOSTNAME}
fi

# -------------------------------------------------------------------------------------------------

exec "$@"

# EOF
