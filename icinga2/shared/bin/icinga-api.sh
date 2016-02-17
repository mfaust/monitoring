#!/bin/bash

API_USER="root"
API_PASS="icinga"
curl_opts="-u ${API_USER}:${API_PASS} -k -s "

addJenkinsNode() {

  if [ $(curl ${curl_opts} -H 'Accept: application/json' -X GET "https://localhost:5665/v1/objects/hosts/${1}" | python -mjson.tool | jq --raw-output '.status' | grep "No objects found" | wc -l) -eq 1 ]
  then
    curl --silent ${curl_opts} -H 'Accept: application/json' -X PUT "https://localhost:5665/v1/objects/hosts/${1}" --data "{\"templates\":[\"generic-host\"],\"attrs\":{\"address\":\"${1}\",\"display_name\":\"${2}\",\"notes\":\"Jenkins\",\"vars.type\":\"jenkins\"}}"
  fi
}

addChefNode() {

  if [ $(curl ${curl_opts} -H 'Accept: application/json' -X GET "https://localhost:5665/v1/objects/hosts/${1}" | python -mjson.tool | jq --raw-output '.status' | grep "No objects found" | wc -l) -eq 1 ]
  then
    curl --silent ${curl_opts} -H 'Accept: application/json' -X PUT "https://localhost:5665/v1/objects/hosts/${1}" --data "{\"templates\":[\"generic-host\"],\"attrs\":{\"address\":\"${1}\",\"display_name\":\"${2}\",\"notes\":\"Chef\",\"vars.type\":\"chef\"}}"
  fi
}

#if [ $(icinga2 feature list | grep "Enabled" | grep api | wc -l) -eq 1 ]
#then

  addJenkinsNode "pc-ci.coremedia.com" "jenkins - pc-ci"
  addJenkinsNode "cm7-ci.coremedia.com" "jenkins - cm7-ci"
  addJenkinsNode "release-ci.coremedia.com" "jenkins - release-ci"

  addChefNode "chef-server.coremedia.com" "Chef"
  addChefNode "supermarket.coremedia.com" "Chef Supermarket"

#else
#  echo " => API feature not enabled"
#fi

exit 0
