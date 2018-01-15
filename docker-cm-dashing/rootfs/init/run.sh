#!/bin/sh

AUTH_TOKEN=${AUTH_TOKEN:-$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)}

export WORK_DIR=/srv

# -------------------------------------------------------------------------------------------------

# . /init/icinga_cert.sh
. /init/configure_smashing.sh

echo -e "\n"
echo " ==================================================================="
echo "  AUTH_TOKEN set to '${AUTH_TOKEN}'"
echo " ==================================================================="
echo ""

# -------------------------------------------------------------------------------------------------

echo -e "\n Starting Supervisor.\n\n"

if [ -f /etc/supervisord.conf ]
then
  /usr/bin/supervisord -c /etc/supervisord.conf >> /dev/null
fi


# EOF
