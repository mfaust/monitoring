
CoreMedia grafana client
========================

# short Description

The grafana client use the message queue service.

This service runs every `INTERVAL` seconds.


# Environment Variables

| Environmental Variable      | Default Value        | Description                                                     |
| :-------------------------- | :-------------       | :-----------                                                    |
| `GRAFANA_HOST`              | `grafana`            | grafana Host                                                    |
| `GRAFANA_PORT`              | `80`                 | grafana Port                                                    |
| `GRAFANA_URL_PATH`          | `/grafana`           | grafana URL Path                                                |
| `GRAFANA_API_USER`          | `admin`              | grafana API user                                                |
| `GRAFANA_API_PASSWORD`      | `admin`              | grafana API password                                            |
| `GRAFANA_TEMPLATE_PATH`     | `/usr/local/share/templates/grafana` | database schema name for the discovery service  |
| `MQ_HOST`                   | `beanstalkd`         | beanstalkd (message queue) Host                                 |
| `MQ_PORT`                   | `11300`              | beanstalkd (message queue) Port                                 |
| `MQ_QUEUE`                  | `mq-grafana`         | beanstalkd (message queue) Queue                                |
| `REDIS_HOST`                | `redis`              | redis Host                                                      |
| `REDIS_PORT`                | `6379`               | redis Port                                                      |
| `MYSQL_HOST`                | `database`           | database Host                                                   |
| `DISCOVERY_DATABASE_NAME`   | `discovery`          | database schema name for the discovery service                  |
| `DISCOVERY_DATABASE_USER`   | `discovery`          | database user for the discovery service                         |
| `DISCOVERY_DATABASE_PASS`   | `discovery`          | database password for the discovery service                     |
| `INTERVAL`                  | `40`                 | run interval for the scheduler                                  |
| `RUN_DELAY`                 | `30`                 | delay for the first run                                         |
| `SERVER_CONFIG_FILE`        | `/etc/grafana/server_config.yml` | configure file for grafana |
