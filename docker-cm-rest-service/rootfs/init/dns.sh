#
#
#

set -e

# -------------------------------------------------------------------------------------------------

addDNS() {

  hosts=

  if [ -n "${ADDITIONAL_DNS}" ]
  then

    while ! nc -z dnsdock 80
    do
      echo -n " ."
      sleep 5s
    done
    echo " "

    sleep 2s

    hosts=$(echo ${ADDITIONAL_DNS} | sed -e 's/,/ /g' -e 's/\s+/\n/g' | uniq)
  fi


  if [ -z "${hosts}" ]
  then
    echo "no hosts for add to dns"
  else

    for h in ${hosts}
    do
      echo "${h}"

      host=$(echo "${h}" | cut -d: -f1)
      ip=$(echo "${h}" | cut -d: -f2)
      aliases=

      [ -n "${host}" ]
      [ -n "${ip}" ]

      if [ "${host}" == "blueprint-box" ]
      then
        aliases="\"aliases\":[\"${host}\", \"${ip}.xip.io\"]"
      else
        aliases="\"aliases\":[\"${host}\"]"
      fi

      echo "add host '${host}' with ip '${ip}' to dns"

      curl \
        http://dnsdock/services/${host} \
        --silent \
        --request PUT \
        --data-ascii "{\"name\":\"${host}.docker\",\"image\":\"${host}\",\"ips\":[\"${ip}\"],\"ttl\":0,${aliases}}"

    done

  fi

}

addDNS
