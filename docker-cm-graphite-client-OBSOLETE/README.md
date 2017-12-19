
CoreMedia graphite client
========================

# short Description

The graphite client use the message queue service and creates only annotations.

This service runs every `INTERVAL` seconds and starts after `RUN_DELAY`.


# Environment Variables

| Environmental Variable             | Default Value        | Description                            |
| :--------------------------------  | :-------------       | :-----------                           |
| `GRAPHITE_HOST`                    | `localhost`          | graphite Host                          |
| `GRAPHITE_PORT`                    | `2003`               | graphite carbon Port                   |
| `GRAPHITE_HTTP_PORT`               | `8081`               | graphite HTTP Path                     |
| `GRAPHITE_PATH`                    | ``                   | graphite Path                          |
| `MQ_HOST`                          | `beanstalkd`         | beanstalkd (message queue) Host        |
| `MQ_PORT`                          | `11300`              | beanstalkd (message queue) Port        |
| `MQ_QUEUE`                         | `mq-collector`       | beanstalkd (message queue) Queue       |
| `INTERVAL`                         | `30`                 | run interval for the scheduler         |
| `RUN_DELAY`                        | `10`                 | delay for the first run                |

