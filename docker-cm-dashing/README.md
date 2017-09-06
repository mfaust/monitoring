
CoreMedia smashing
========================

# short Description

A small and powerful dashboard system.

Bases on [bodsch/docker-smashing](https://hub.docker.com/r/bodsch/docker-smashing/)


# Environment Variables

| Environmental Variable             | Default Value        | Description                                                     |
| :--------------------------------- | :-------------       | :-----------                                                    |
| `ICINGA_HOST`                      | `icinga2`            | icinga2 Host                                                    |
| `ICINGA_API_PORT`                  | `5665`               | icinga2 API Port                                                |
| `ICINGA_API_USER`                  | `admin`              | icinga2 API User                                                |
| `ICINGA_API_PASSWORD`              | ``                   | icinga2 API Password                                            |
| `ICINGA_CLUSTER`                   | `false`              | icinga2 Cluster Mode                                            |
| `ICINGA_CLUSTER_SATELLITE`         | ``                   | icinga2 Cluster Satellite                                       |
|                                    |                      |                                                                 |
| `ICINGA_CERT_SERVICE`              | `false`              | enable the Icinga2 Certificate Service                          |
| `ICINGA_CERT_SERVICE_BA_USER`      | `admin`              | The Basic Auth User for the certicate Service                   |
| `ICINGA_CERT_SERVICE_BA_PASSWORD`  | `admin`              | The Basic Auth Password for the certicate Service               |
| `ICINGA_CERT_SERVICE_API_USER`     | -                    | The Certificate Service needs also an API Users                 |
| `ICINGA_CERT_SERVICE_API_PASSWORD` | -                    |                                                                 |
| `ICINGA_CERT_SERVICE_SERVER`       | `localhost`          | Certificate Service Host                                        |
| `ICINGA_CERT_SERVICE_PORT`         | `80`                 | Certificate Service Port                                        |
| `ICINGA_CERT_SERVICE_PATH`         | `/`                  | Certificate Service Path (needful, when they run begind a Proxy |
| `ICINGAWEB_URL`                    | `http://localhost/icingaweb2` | (not yet used)                                         |
