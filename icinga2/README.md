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


Start a new container and bind to host's port 80 and 5665 with using DNS 10.1.2.14 and 10.1.2.63

    sudo docker run --dns=10.1.2.14 --dns=10.1.2.63 --publish=80:80 --publish=5665:5665 icinga2

Start a new container and supply the icinga and icinga_web password

    sudo docker run -e ICINGA_PASSWORD="icinga" -e ICINGA_WEB_PASSWORD="icinga_web" -t icinga2:latest

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
