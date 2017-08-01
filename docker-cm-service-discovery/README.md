
CoreMedia service discovery
========================

# short Description

A service discovery for CoreMedia Applications.


# Environment Variables

| Environmental Variable             | Default Value        | Description                                                     |
| :--------------------------------- | :-------------       | :-----------                                                    |
| `JOLOKIA_HOST`                     | `jolokia`            | jolokia Host                                                    |
| `JOLOKIA_PORT`                     | `8080`               | jolokia Port                                                    |
| `JOLOKIA_PATH`                     | `/jolokia`           | jolokia Path                                                    |
| `JOLOKIA_AUTH_USER`                | ``                   | jolokia authenication user (not yet supported)                  |
| `JOLOKIA_AUTH_PASS`                | ``                   | jolokia authenication password (not yet supported)              |
| `MQ_HOST`                          | `beanstalkd`         | beanstalkd (message queue) Host                                 |
| `MQ_PORT`                          | `11300`              | beanstalkd (message queue) Port                                 |
| `MQ_QUEUE`                         | `mq-discover`        | beanstalkd (message queue) Queue                                |
| `REDIS_HOST`                       | `redis`              | redis Host                                                      |
| `REDIS_PORT`                       | `6379`               | redis Port                                                      |
| `MYSQL_HOST`                       | `database`           | database Host                                                   |
| `DISCOVERY_DATABASE_NAME`          | `discovery`          | database schema name for the discovery service                  |
| `DISCOVERY_DATABASE_USER`          | `discovery`          | database user for the discovery service                         |
| `DISCOVERY_DATABASE_PASS`          | `discovery`          | database password for the discovery service                     |
| `INTERVAL`                         | `20`                 | run interval for the scheduler                                  |
| `RUN_DELAY`                        | `10`                 | delay for the first run                                         |
