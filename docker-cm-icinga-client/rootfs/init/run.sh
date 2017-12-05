#!/bin/sh

export WORK_DIR=/srv

# -------------------------------------------------------------------------------------------------

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
