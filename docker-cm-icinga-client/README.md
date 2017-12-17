
CoreMedia Icinga2 Client
========================

# short Description

The icinga2 client use the message queue service and creates only Nodes on a icinga2-master.

This service runs every `INTERVAL` seconds.

It use the [icinga-gem](https://rubygems.org/gems/icinga2) for API Calls.



# Environment Variables

| Environmental Variable             | Default Value        | Description                                                     |
| :--------------------------------- | :-------------       | :-----------                                                    |
| `ICINGA_HOST`                      | `localhost`          | icinga2 Host                                                    |
| `ICINGA_API_PORT`                  | `5665`               | icinga2 API Port                                                |
| `ICINGA_API_USER`                  | `admin`              | icinga2 API User                                                |
| `ICINGA_API_PASSWORD`              | ``                   | icinga2 API Password                                            |
| `ICINGA_CLUSTER`                   | `false`              | icinga2 Cluster Mode                                            |
| `ICINGA_CLUSTER_SATELLITE`         | ``                   | icinga2 Cluster Satellite                                       |
| `ICINGA_CERT_SERVICE`              | ``                   | json with configuration parameters for the used *certificate-server* (see below) |
| `SERVER_CONFIG_FILE`               | `/etc/icinga_server_config.yml` | configuration file to add `contact-groups` and `-users` |
| `ENABLE_NOTIFICATIONS`             | `false`              | icinga2 notification enabled                                    |
| `MQ_HOST`                          | `beanstalkd`         | beanstalkd (message queue) Host                                 |
| `MQ_PORT`                          | `11300`              | beanstalkd (message queue) Port                                 |
| `MQ_QUEUE`                         | `mq-icinga`          | beanstalkd (message queue) Queue                                |
| `MYSQL_HOST`                       | `database`           | database Host                                                   |
| `DISCOVERY_DATABASE_NAME`          | `discovery`          | database schema name for the discovery service                  |
| `DISCOVERY_DATABASE_USER`          | `discovery`          | database user for the discovery service                         |
| `DISCOVERY_DATABASE_PASS`          | `discovery`          | database password for the discovery service                     |
| `INTERVAL`                         | `20s`                | run interval for the scheduler (minimum are `20s`)              |
| `RUN_DELAY`                        | `10s`                | delay for the first run                                         |

For all Scheduler Variables, you can use simple integer values like `10`, this will be interpreted as `second`.
Other Values are also possible:
  - `1h` for 1 hour
  - `1w` for 1 week

Kombinations are also possible:
  - `5m10s` for 5 minutes and 10 seconds
  - `1h10s` for 1 hour and 20 minutes



## example

To use the TLS Encryption between the Icinga2 Master and this Icinga2 Client, we need an TLS Zertificate from the Master.
To get them, we can use the integrated *icinga2-cert-service*
The following example is anvalid configuration to use this service.
Whitout an TLS Certificate, we can not use the `SERVER_CONFIG_FILE`

```bash
ICINGA_CERT_SERVICE='{
  "ba": { "user":"admin", "password":"admin" },
  "api": { "user":"root", "password":"icinga" },
  "server": "cm-icinga2-master",
  "port": 4567,
  "path": "/"
}'
```
