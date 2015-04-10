#!/bin/bash

while getopts "i:t:f:" OPTION
do
  case $OPTION in
    i)
    IMAGE=$OPTARG
    ;;
    t)
    TAG=$OPTARG
    ;;
    f)
    FOLDER=$OPTARG
    ;;
  esac
done

if [ -n "$TAG" ]
  then
  TAG=:$TAG
fi

docker build --no-cache=true -t=coremedia/$IMAGE$TAG $FOLDER/
docker login -u coremedia -p $DOCKER_HUB_PASSWORD
docker push coremedia/$IMAGE$TAG
