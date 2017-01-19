#!/bin/bash
#
# PoC
# not usable in a docker container
# siege needs to much ressources


cd /var/tmp

base="media"

url="master71-ci-tomcat.coremedia.vm"

getUrls() {

  local media=$1

  lynx -dump -listonly http://${base}.${url} | awk -F' ' '{print $2}' | sort | uniq > ${media}.${url}.urls
# | grep "http://${media}.${url}" | awk -F' ' '{print $2}' | sort | uniq > ${media}.${url}.urls
}

getUrls "media"
getUrls "corporate"
getUrls "helios"

#siege --file=/var/tmp/media.${url}.urls
#siege --file=/var/tmp/corporate.${url}.urls
#siege --file=/var/tmp/helios.${url}.urls
