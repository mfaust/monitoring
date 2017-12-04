#!/bin/sh

directory="/var/lib/icinga2/api/packages/_api/${HOSTNAME}*/conf.d/hosts/"

inotifywait \
  --monitor ${directory} \
  --event modify \
  --event close_write \
  --event delete |
  while read path action file; do
    echo "The file '$file' appeared in directory '$path' via '$action'"
    killall icinga2
    # do something with the file
  done
