#!/bin/sh

exec  /usr/bin/beanstalkd -b /var/cache/beanstalkd -f 0 &
