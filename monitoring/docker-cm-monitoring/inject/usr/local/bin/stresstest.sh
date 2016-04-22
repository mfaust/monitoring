#!/bin/bash

cd /var/tmp

base="media"


getUrls() {

  local media=$1

  lynx -dump -listonly http://${base}.192.168.252.100.xip.io | grep "http://${media}.192.168.252.100.xip.io" | awk -F' ' '{print $2}' | sort | uniq > ${media}.192.168.252.100.urls
}

getUrls "media"
getUrls "corporate"
getUrls "helios"

siege --file=/var/tmp/media.192.168.252.100.urls
siege --file=/var/tmp/corporate.192.168.252.100.urls
siege --file=/var/tmp/helios.192.168.252.100.urls
