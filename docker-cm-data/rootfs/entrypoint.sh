#!/bin/sh

rm -rf /share/*

mv -v /data/* /share
echo "finished" > /share/finished

exec "$@"
