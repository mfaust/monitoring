#
#
#

set -e
set -x

# -------------------------------------------------------------------------------------------------

isIp() {

  TEST=$(echo "${IP}." | grep -E "([0-9]{1,3}\.){4}")

  if [ "$TEST" ]
  then
    echo "$IP" | awk -F. '{
      if ( (($1>=0) && ($1<=255)) &&
           (($2>=0) && ($2<=255)) &&
           (($3>=0) && ($3<=255)) &&
           (($4>=0) && ($4<=255)) ) {
        print 0
#         print($0 " is a valid IP address.");
      } else {
        print 1
#        print($0 ": IP address out of range!");
      }
    }'
  else
    echo 1
#    echo "${IP} is not a valid IP address!"
  fi
}

checkIP() {

  if [ $(isIp ${1}) -eq 1 ]
  then
    name=$(host -t A ${1} | grep "has address" | cut -d ' ' -f 4)

    if [ -z ${name} ]
    then
      echo ${1}
    else
      echo ${name}
    fi
#    echo $(host -t A ${1} | grep "has address" | cut -d ' ' -f 4)
  else
    echo ${1}
  fi
}


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

    if [ ! -z "${hosts}" ]
    then
      for h in ${hosts}
      do
        echo "${h}"

        host=$(echo "${h}" | cut -d: -f1)
        ip=$(echo "${h}" | cut -d: -f2)
        aliases=

        [ -n "${host}" ]
        [ -n "${ip}" ]

        ip="$(checkIP ${ip})"

        if [ -z ${ip} ]
        then
          echo " [E] - the ip can't resolve! :("
          continue
        fi

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
  fi
}

addDNS
