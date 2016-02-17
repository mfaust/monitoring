# icinga2

This repository contains the source for the
[icinga2](https://www.icinga.org/icinga2/) [docker](https://www.docker.com)
image.

## Image details

1. Based on debian:jessie
1. Supervisor, Apache2, MariaDB, icinga2 and icingaweb2
1. No SSH.  Use sudo docker exec -it <CONTAINER_NAME> bash or [nsenter](https://github.com/jpetazzo/nsenter)
1. If no passwords are not supplied, they will be randomly generated and shown via stdout.

## Usage

Build the Container

    sudo docker build -t icinga2 --rm=true --force-rm=true .

    or

    ./build.sh

Start a new container and bind to host's port 80 and 5665 with using DNS 10.1.2.14 and 10.1.2.63

    sudo docker run --dns=10.1.2.14 --dns=10.1.2.63 --publish=80:80 --publish=5665:5665 --volume=${PWD}/shared/icinga2:/usr/local/share/icinga2  icinga2

    or

    ./run.sh

After start, the icinga2 Service are up and running (hopefully).
Now you can add some Nodes via ReST-API

    ./shared/bin/icinga-api.sh

The Script add currently some Infrastructur Nodes (eg. pc-ci.coremedia.com, chef-server.coremedia.com and so on) with an set an small Service-Checks.

## Icinga Web 2

Icinga Web 2 can be accessed at http://localhost/icingaweb2 with the credentials icingaadmin:icinga

## Environment variables & Volumes

```
ICINGA_PASSWORD
ICINGAWEB2_PASSWORD
IDO_PASSWORD
DEBIAN_SYS_MAINT_PASSWORD
```

```
/etc/icinga2
/etc/icingaweb2
/var/lib/mysql
/var/lib/icinga2
```

## NOTES

All Checkresults, Checks and other modifications are *not persitent*!