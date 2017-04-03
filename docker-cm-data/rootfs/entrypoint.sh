#!/bin/sh

mv /data/* /share
echo "finished" > /share/finished

exec "$@"