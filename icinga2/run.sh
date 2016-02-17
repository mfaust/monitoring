#!/bin/bash


sudo docker run --tty=false --interactive=false --dns=10.1.2.14 --dns=10.1.2.63 --publish=80:80 --publish=5665:5665 bodsch-icinga2

# EOF
