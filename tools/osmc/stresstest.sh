#!/bin/bash
#
# PoC
# not usable in a docker container
# siege needs to much ressources

notification=""

monitoring="moebius-monitoring.coremedia.vm"
url="moebius-ci-02-moebius-tomcat-0-cms.coremedia.vm"
sitemap="https://corporate.${url}/service/sitemap/abffe57734feeee/sitemap1.xml.gz"

finish() {

  curl \
    --request POST \
    --data '{ "command": "loadtest", "argument": "stop" }' \
    http://${monitoring}/api/v2/annotation/${url}

  exit 0
}

start() {

  curl \
    --request POST \
    --data '{ "command": "loadtest", "argument": "start" }' \
    http://${monitoring}/api/v2/annotation/${url}
}

# Signale SIGINT abfangen
trap 'finish' SIGINT SIGTERM

cd /var/tmp

rm -f sitemap* 2> /dev/null
rm -f *.urls   2> /dev/null


url_list() {
  local media=$1
  local query=$2
  lynx -dump -listonly http://${media}.${url}/${query} | awk -F' ' '{print $2}' | sort | uniq > ${media}.${url}-${query}.urls
}

# http://corporate.${url}/corporate-de-de

sitemap() {

  [[ -f sitemap1.xml.gz ]] && rm -f sitemap1.xml.gz

  curl -k \
    --output sitemap1.xml.gz \
    ${sitemap}

  if [[ -f sitemap1.xml.gz ]]
  then
    gunzip sitemap1.xml.gz

    grep "<url><loc>" sitemap1.xml | sed -e 's|</loc></url>||g' -e 's|<url><loc>||g' | sort | uniq > sitemap.urls
  else
    echo "no sitemap found"
 fi

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

cat ${url}.tmp | sort | uniq | grep "${url}" > ${url}.url

rm -f ${url}.tmp
rm -f *.urls


start

siege --benchmark --concurrent=15 --file=${url}.url --time=10m

finish

