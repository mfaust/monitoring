#!/bin/sh

initfile=/opt/run.init

AUTH_TOKEN=${AUTH_TOKEN:-$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)}
ICINGA2_HOST=${ICINGA2_HOST:-""}
ICINGA2_PORT=${ICINGA2_PORT:-"5665"}
ICINGA2_DASHING_APIUSER=${ICINGA2_DASHING_APIUSER:-"dashing"}
ICINGA2_DASHING_APIPASS=${ICINGA2_DASHING_APIPASS:-"icinga"}

GRAPHITE_HOST=${GRAPHITE_HOST:-""}
GRAPHITE_PORT=${GRAPHITE_PORT:-8080}

DASHBOARD=${DASHBOARD:-coremedia}

DASHING_PATH="/opt/dashing/${DASHBOARD}"
CONFIG_FILE="${DASHING_PATH}/config.ru"

# -------------------------------------------------------------------------------------------------

if [ ! -f "${initfile}" ]
then

  if [ -f ${CONFIG_FILE} ]
  then
    sed -i 's,%AUTH_TOKEN%,'${AUTH_TOKEN}',g' ${CONFIG_FILE}
  fi

  if [ ! -z ${ICINGA2_HOST} ]
  then

    if [ -f ${DASHING_PATH}/config/icinga2.yml ]
    then
      sed -i \
        -e 's/%ICINGA2_HOST%/'${ICINGA2_HOST}'/g' \
        -e 's/%ICINGA2_PORT%/'${ICINGA2_PORT}'/g' \
        -e 's/%ICINGA2_DASHING_APIUSER%/'${ICINGA2_DASHING_APIUSER}'/g' \
        -e 's/%ICINGA2_DASHING_APIPASS%/'${ICINGA2_DASHING_APIPASS}'/g' \
        ${DASHING_PATH}/config/icinga2.yml
    fi
  else
    rm -f ${DASHING_PATH}/jobs/icinga2.rb
  fi

  if [ ! -z ${GRAPHITE_HOST} ]
  then

    if [ -f ${DASHING_PATH}/config/graphite.yml ]
    then
      sed -i \
        -e 's/%GRAPHITE_HOST%/'${GRAPHITE_HOST}'/g' \
        -e 's/%GRAPHITE_PORT%/'${GRAPHITE_PORT}'/g' \
        ${DASHING_PATH}/config/graphite.yml
    fi
  else
    rm -f ${DASHING_PATH}/jobs/graphite.rb
  fi

  if [ -z ${PINGDOM_USER} ]
  then
    echo "missing pingdom credentials, removing job .."
    rm -f  ${DASHING_PATH}/job/pingdom.rb
  fi

  if [ -z ${AWS_ACCESS_KEY_ID} ]
  then
    echo "missing AWS credentials, removing jobs .."
    rm -f  ${DASHING_PATH}/job/cloud*.rb
  fi

  if [ -z ${CHEF_KNIFE_RB} ]
  then
    echo "missing Chef credentials, removing jobs .."
    rm -f  ${DASHING_PATH}/job/chef.rb
  fi


  touch ${initfile}

  echo -e "\n"
  echo " ==================================================================="
  echo " Dashing AUTH_TOKEN set to '${AUTH_TOKEN}'"
  echo " ==================================================================="
  echo ""

fi

# -------------------------------------------------------------------------------------------------

echo -e "\n Starting Supervisor.\n\n"

if [ -f /etc/supervisord.conf ]
then
  /usr/bin/supervisord -c /etc/supervisord.conf >> /dev/null
fi


# EOF
