#!/bin/sh

AUTH_TOKEN=${AUTH_TOKEN:-$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)}

export WORK_DIR=/srv

# -------------------------------------------------------------------------------------------------

. /init/output.sh
. /init/icinga_cert.sh
. /init/configure_smashing.sh

log_info "==================================================================="
log_info " Dashing AUTH_TOKEN set to '${AUTH_TOKEN}'"
log_info "==================================================================="

# -------------------------------------------------------------------------------------------------


log_info "start init process ..."

cd /opt/${DASHBOARD}

/usr/bin/puma \
  --quiet \
  --config /opt/${DASHBOARD}/config/puma.rb



# /usr/bin/thin \
#   --pid /tmp/thin.pid \
#   --quiet \
#   --log /dev/stdout \
#   --port 3030 \
#   --chdir /opt/${DASHBOARD} \
#   --environment production \
#   --rackup /opt/${DASHBOARD}/config.ru \
#   start

#log_info "Starting Supervisor."
#
#if [ -f /etc/supervisord.conf ]
#then
#  /usr/bin/supervisord -c /etc/supervisord.conf >> /dev/null
#fi


# EOF
