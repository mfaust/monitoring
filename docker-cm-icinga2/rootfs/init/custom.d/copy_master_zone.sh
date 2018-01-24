#!/bin/sh

. /init/output.sh

log_info " ------------------------------------------------------ "
log_info " create custom master zone"

if [[ "${ICINGA_TYPE}" = "Master" ]]
then

  [[ -d /etc/icinga2/zones.d/global-templates ]] || mkdir -p /etc/icinga2/zones.d/global-templates

  template_file="/etc/icinga2/zones.d/global-templates/coremedia_templates.conf"

  if [[ ! -f ${template_file} ]]
  then
    if [[ $(grep -c 'template Host "default-host-ping"' ${template_file}) -eq 0 ]]
    then
      cat << EOF > /etc/icinga2/zones.d/global-templates/coremedia_templates.conf

/** CoreMedia specific Host Template */

template Host "default-host-ping" {
  check_command                   = "fping4"
  max_check_attempts              = 5
  check_period                    = "24x7"
  check_interval                  = 3m
  retry_interval                  = 2m
  enable_notifications            = true
  vars.fping_wrta                 = 1000
  vars.fping_wpl                  = 100
  vars.fping_crta                 = 2000
  vars.fping_cpl                  = 100
  vars.fping_number               = 2
  vars.fping_interval             = 500
}
EOF
    fi
  fi
fi

log_info " ------------------------------------------------------ "
