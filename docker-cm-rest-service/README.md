
CoreMedia Monitoring REST
========================

# short Description

The monitoring REST API is the user entry point.


# Environment Variables

| Environmental Variable             | Default Value        | Description                                                     |
| :--------------------------------- | :-------------       | :-----------                                                    |
| `REST_SERVICE_PORT`                | `4567`               | REST Service Port                                               |
| `REST_SERVICE_BIND`                | `0.0.0.0`            | REST Service bind-address                                       |
| `MQ_HOST`                          | `beanstalkd`         | beanstalkd (message queue) Host                                 |
| `MQ_PORT`                          | `11300`              | beanstalkd (message queue) Port                                 |
| `MQ_QUEUE`                         | `mq-rest-service`    | beanstalkd (message queue) Queue                                |
| `REDIS_HOST`                       | `redis`              | redis Host                                                      |
| `REDIS_PORT`                       | `6379`               | redis Port                                                      |
| `MYSQL_HOST`                       | `database`           | database Host                                                   |
| `DISCOVERY_DATABASE_NAME`          | `discovery`          | database schema name for the discovery service                  |
| `DISCOVERY_DATABASE_USER`          | `discovery`          | database user for the discovery service                         |
| `DISCOVERY_DATABASE_PASS`          | `discovery`          | database password for the discovery service                     |
| `ADDITIONAL_DNS`                   | ``                   | additional DNS (only useful with `dnsdock`)                     |
|                                    |                      | comma separated list to create dns entries.                     |
|                                    |                      | format `hostname:ip`                                            |
|                                    |                      | (e.g. `blueprint-box:192.168.252.100,tomcat-centos7:192.168.252.100` and so on) |
| `INTERVAL`                         | `30`                 | run interval for the scheduler                                  |
| `RUN_DELAY`                        | `10`                 | delay for the first run                                         |

