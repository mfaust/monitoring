#!/bin/bash
#
# PoC
# not usable in a docker container
# siege needs to much ressources

set +x

notification=""


finish() {

  curl \
    --request POST \
    --data '{ "command": "loadtest", "argument": "stop" }' \
    http://localhost/api/v2/annotation/osmc.local

  exit 0
}

# Signale SIGINT abfangen
trap 'finish' SIGINT SIGTERM

cd /var/tmp

rm -f sitemap* 2> /dev/null
rm -f *.urls   2> /dev/null


url="osmc.local"

url_list() {
  local media=$1
  local query=$2
  lynx -dump -listonly http://${media}.osmc.local/${query} | awk -F' ' '{print $2}' | sort | uniq > ${media}.osmc.local-${query}.urls
}

# http://corporate.osmc.local/corporate-de-de

sitemap() {

  curl -k \
    --output sitemap1.xml.gz \
    https://corporate.osmc.local/service/sitemap/abffe57734feeee/sitemap1.xml.gz

  gunzip sitemap1.xml.gz

  grep "<url><loc>" sitemap1.xml | sed -e 's|</loc></url>||g' -e 's|<url><loc>||g' | sort | uniq > sitemap.urls

}

sitemap
url_list "corporate" "corporate"
url_list "corporate" "corporate-de-de"
url_list "preview" "corporate"
url_list "preview" "corporate-de-de"

for f in $(ls -1 *.urls | sort)
do
  cat $f >> ${url}.tmp
done

cat ${url}.tmp | sort | uniq | grep "osmc.local" > ${url}.url

rm -f ${url}.tmp
rm -f *.urls

curl \
  --request POST \
  --data '{ "command": "loadtest", "argument": "start" }' \
  http://localhost/api/v2/annotation/osmc.local


siege --benchmark --concurrent=15 --file=${url}.url --time=10m

finish

