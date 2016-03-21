#!/bin/sh

[ -d "/run/mysqld" ] || mkdir -vp /run/mysqld

if [ -d /app/mysql ]
then
  echo " [i] MySQL directory already present, skipping creation"
else
  echo " [i] MySQL data directory not found, creating initial DBs"

  mysql_install_db --user=root > /dev/null

  MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD:-$(pwgen -s 15 1)}

  MYSQL_DATABASE=${MYSQL_DATABASE:-""}
  MYSQL_USER=${MYSQL_USER:-""}
  MYSQL_PASSWORD=${MYSQL_PASSWORD:-""}

  if [ ! -d "/run/mysqld" ]; then
    mkdir -p /run/mysqld
  fi

  tfile="/app/bootstrap"

  cat << EOF > $tfile
USE mysql;
FLUSH PRIVILEGES;
create user 'root'@'%' IDENTIFIED BY "${MYSQL_ROOT_PASSWORD}";
GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION;
GRANT ALL PRIVILEGES ON *.* TO 'root'@'localhost' WITH GRANT OPTION;
UPDATE user SET password=PASSWORD("") WHERE user='root' AND host='localhost';
FLUSH PRIVILEGES;
EOF

  if [ "$MYSQL_DATABASE" != "" ]
  then
    echo " [i] Creating database: $MYSQL_DATABASE"
    echo "CREATE DATABASE IF NOT EXISTS \`$MYSQL_DATABASE\` CHARACTER SET utf8 COLLATE utf8_general_ci;" >> $tfile

    if [ "$MYSQL_USER" != "" ]
    then
      echo " [i] Creating user: $MYSQL_USER with password $MYSQL_PASSWORD"
      echo "GRANT ALL ON \`$MYSQL_DATABASE\`.* to '$MYSQL_USER'@'%' IDENTIFIED BY '$MYSQL_PASSWORD';" >> $tfile
    fi
  fi

  /usr/bin/mysqld --user=root --bootstrap --verbose=0 < $tfile
#  rm -f $tfile

  echo -e "\n"
  echo " ==================================================================="
  echo " MySQL user 'root' password set to '${MYSQL_ROOT_PASSWORD}'"
  echo " ==================================================================="
  echo ""

fi

echo -e "\n Starting Supervisor.\n  You can safely CTRL-C and the container will continue to run with or without the -d (daemon) option\n\n"

if [ -f /etc/supervisord.conf ]
then
  /usr/bin/supervisord -c /etc/supervisord.conf >> /dev/null
fi


# EOF
