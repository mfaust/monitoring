
CoreMedia icinga2 client
========================

# short Description

The icinga2 client use the message queue service and creates only Nodes on a icinga2-master.

This service runs every `INTERVAL` seconds.

It use the [icinga-gem](https://rubygems.org/gems/icinga2) for AÜI Calls.



# Environment Variables

| Environmental Variable             | Default Value        | Description                                                     |
| :--------------------------------- | :-------------       | :-----------                                                    |
| `ICINGA_HOST`                      | `localhost`          | icinga2 Host                                                    |
| `ICINGA_API_PORT`                  | `5665`               | icinga2 API Port                                                |
| `ICINGA_API_USER`                  | `admin`              | icinga2 API User                                                |
| `ICINGA_API_PASSWORD`              | ``                   | icinga2 API Password                                            |
| `ICINGA_CLUSTER`                   | `false`              | icinga2 Cluster Mode                                            |
| `ICINGA_CLUSTER_SATELLITE`         | ``                   | icinga2 Cluster Satellite                                       |
| `ENABLE_NOTIFICATIONS`             | `false`              | icinga2 notification enabled                                    |
| `MQ_HOST`                          | `beanstalkd`         | beanstalkd (message queue) Host                                 |
| `MQ_PORT`                          | `11300`              | beanstalkd (message queue) Port                                 |
| `MQ_QUEUE`                         | `mq-icinga`          | beanstalkd (message queue) Queue                                |
| `MYSQL_HOST`                       | `database`           | database Host                                                   |
| `DISCOVERY_DATABASE_NAME`          | `discovery`          | database schema name for the discovery service                  |
| `DISCOVERY_DATABASE_USER`          | `discovery`          | database user for the discovery service                         |
| `DISCOVERY_DATABASE_PASS`          | `discovery`          | database password for the discovery service                     |
| `INTERVAL`                         | `20`                 | run interval for the scheduler                                  |
| `RUN_DELAY`                        | `10`                 | delay for the first run                                         |
