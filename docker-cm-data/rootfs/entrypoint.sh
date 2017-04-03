#!/bin/sh

rm -rf /share/*

mv /data/* /share
echo "finished" > /share/finished

exec "$@"
