#!/bin/bash

HOST="moebius-ci-02-moebius-tomcat-0-cms.coremedia.vm"
#HOST="192.168.252.100.xip.io"
#HOST="pandora-17-02.coremedia.vm"

rm -v *.urls

getUrls() {

  local base=$1

  lynx -force_secure -dump -listonly http://${base} | grep "http://${base}" | awk -F' ' '{print $2}' | grep -v LYNXIMGMAP | grep -v "coremedia.vm:4" | sort | uniq >> ${HOST}.urls
}

for i in preview.${HOST}/corporate-de-de preview.${HOST}/corporate shop-helios.${HOST}/webapp/wcs/stores/servlet/en/aurorab2besite shop-preview-production-helios.${HOST}/webapp/wcs/stores/servlet/en/auroraesite
do
  getUrls $i
done

getUrls ${HOST}
#getUrls "corporate"
#getUrls "helios"


# cat media.192.168.252.100.urls corporate.192.168.252.100.urls helios.192.168.252.100.urls > 192.168.252.100.urls

siege --benchmark --file=${HOST}.urls --time=20m

# rm -fv *.urls
