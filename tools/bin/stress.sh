#!/bin/bash

HOST="monitoring-16-01.coremedia.vm"

rm -v *.urls

getUrls() {

  local base=$1

  lynx -force_secure -dump -listonly http://${base} | grep "http://${base}" | awk -F' ' '{print $2}' | grep -v LYNXIMGMAP | grep -v "coremedia.vm:4" | sort | uniq >> ${HOST}.urls
}

for i in helios.monitoring-16-01.coremedia.vm preview-helios.monitoring-16-01.coremedia.vm/perfectchef-de-de 
do
  getUrls $i
done

getUrls ${HOST}
#getUrls "corporate"
#getUrls "helios"


# cat media.192.168.252.100.urls corporate.192.168.252.100.urls helios.192.168.252.100.urls > 192.168.252.100.urls

siege -i --file=${HOST}.urls

# rm -fv *.urls