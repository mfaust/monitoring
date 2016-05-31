#!/bin/sh

set -e

initfile=/opt/run.init

DATABASE_GRAPHITE_TYPE=${DATABASE_GRAPHITE_TYPE:-sqlite}
DATABASE_GRAPHITE_HOST=${DATABASE_GRAPHITE_HOST:-""}
DATABASE_GRAPHITE_PORT=${DATABASE_GRAPHITE_PORT:-"3306"}
DATABASE_GRAPHITE_PASS=${DATABASE_GRAPHITE_PASS:-$(pwgen -s 15 1)}
DATABASE_ROOT_USER=${DATABASE_ROOT_USER:-""}
DATABASE_ROOT_PASS=${DATABASE_ROOT_PASS:-""}

STORAGE_PATH=${STORAGE_PATH:-/app}

# -------------------------------------------------------------------------------------------------

prepareStorage() {

  mkdir -p ${STORAGE_PATH}/graphite

  cp -ar /opt/graphite/storage ${STORAGE_PATH}/graphite/

  chown -R nginx ${STORAGE_PATH}/graphite/storage
}

prepareDatabase() {

  local CONFIG_FILE="/opt/graphite/webapp/graphite/local_settings.py"

  if [ ! -f ${CONFIG_FILE} ]
  then
    cp ${CONFIG_FILE}-DIST ${CONFIG_FILE}
  fi

  sed -i \
    -e "s|%STORAGE_PATH%|${STORAGE_PATH}|g" \
    ${CONFIG_FILE}

  if [ "${DATABASE_GRAPHITE_TYPE}" == "sqlite" ]
  then

    if [ -d ${STORAGE_PATH}/graphite/storage ]
    then
      touch ${STORAGE_PATH}/graphite/storage/graphite.db
      touch ${STORAGE_PATH}/graphite/storage/index

      chmod 0664 ${STORAGE_PATH}/graphite/storage/graphite.db
    fi

      sed -i \
        -e "s/%DBA_FILE%/'${STORAGE_PATH}/graphite/storage/graphite.db'/" \
        -e "s/%DBA_ENGINE%//" \
        -e "s/%DBA_USER%//" \
        -e "s/%DBA_PASS%//" \
        -e "s/%DBA_HOST%//" \
        -e "s/%DBA_PORT%//" \
        ${CONFIG_FILE}

  elif [ "${DATABASE_GRAPHITE_TYPE}" == "mysql" ]
  then

      sed -i \
        -e "s/%DBA_FILE%/graphite/" \
        -e "s/%DBA_ENGINE%/mysql/" \
        -e "s/%DBA_USER%/graphite/" \
        -e "s/%DBA_PASS%/${DATABASE_GRAPHITE_PASS}/" \
        -e "s/%DBA_HOST%/${DATABASE_GRAPHITE_HOST}/" \
        -e "s/%DBA_PORT%/${DATABASE_GRAPHITE_PORT}/" \
        ${CONFIG_FILE}

    mysql_opts="--host=${DATABASE_GRAPHITE_HOST} --user=${DATABASE_ROOT_USER} --password=${DATABASE_ROOT_PASS} --port=${DATABASE_GRAPHITE_PORT}"

    if [ -z ${DATABASE_GRAPHITE_HOST} ]
    then
      echo " [E] - i found no DATABASE_GRAPHITE_HOST Parameter for type: '${DATABASE_GRAPHITE_TYPE}'"
    else

      # wait for needed database
      while ! nc -z ${DATABASE_GRAPHITE_HOST} ${DATABASE_GRAPHITE_PORT}
      do
        sleep 3s
      done

      # must start initdb and do other jobs well
      sleep 10s

      (
        echo "--- create user 'graphite'@'%' IDENTIFIED BY '${DATABASE_GRAPHITE_PASS}';"
        echo "CREATE DATABASE IF NOT EXISTS graphite;"
        echo "GRANT SELECT, INSERT, UPDATE, DELETE, DROP, CREATE, CREATE VIEW, ALTER, INDEX, EXECUTE ON graphite.* TO 'graphite'@'%' IDENTIFIED BY '${DATABASE_GRAPHITE_PASS}';"
        echo "FLUSH PRIVILEGES;"
      ) | mysql ${mysql_opts}

    fi

  fi

  chown -R nginx ${STORAGE_PATH}/graphite/storage
}

# -------------------------------------------------------------------------------------------------

if [ ! -f "${initfile}" ]
then

  sed -i 's|^LOCAL_DATA_DIR\ =\ /opt/|LOCAL_DATA_DIR\ =\ '${STORAGE_PATH}'/|g' /opt/graphite/conf/carbon.conf

  prepareStorage
  prepareDatabase

  cd /opt/graphite/webapp/graphite && python manage.py syncdb --noinput

  touch ${initfile}

  echo -e "\n"
  echo " ==================================================================="
  echo "  Database Type    : '${DATABASE_GRAPHITE_TYPE}'"
  echo "  Database Host    : '${DATABASE_GRAPHITE_HOST}'"
  echo "  Database User    : 'graphite'"
  echo "  Database Password: '${DATABASE_GRAPHITE_PASS}'"
  echo "  Storage Path     : '${STORAGE_PATH}'"
  echo " ==================================================================="
  echo ""

fi

echo -e "\n Starting Supervisor.\n\n"

if [ -f /etc/supervisord.conf ]
then
  /usr/bin/supervisord -c /etc/supervisord.conf >> /dev/null
fi


# EOF
