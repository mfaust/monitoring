
CoreMedia aws discovery
=======================

# short Description

A small tool between the AWS API and the CoreMedia Monitoring API.

This service runs every `INTERVAL` seconds.

The AWS Part create an filter to get all relevant instances for the monitoring:

      filter = [
        { name: 'instance-state-name', values: ['running'] },
        { name: 'tag-key'            , values: ['monitoring-enabled'] },
        { name: 'tag:monitoring-enabled', values: ['true'] },
        { name: 'tag:environment'    , values: [AWS_ENVIRONMENT] }
      ]

New instances will automatic added at the CoreMedia Monitoring.
Removed (AWS) instances will automatic removed from the CoreMedia Monitoring.

New created instances are 60 seconds protected to start they services succesfully.

We use also an internal white list of instance types:

        white_list = [
          'management-cms',
          'management-workflow',
          'management-feeder',
          'management-studio',
          'management-caepreview',
          'delivery-backup',
          'delivery-mls',
          'delivery-rls-cae',
          'storage-management-solr',
          'storage-delivery-solr'
        ]

These AWS Tage are important:
 - customer
 - environment
 - tier
 - name
 - cm_apps


# Environment Variables

| Environmental Variable             | Default Value        | Description                                                     |
| :--------------------------------- | :-------------       | :-----------                                                    |
| `MONITORING_HOST`                  | ``                   | CoreMedia Monitoring Host                                       |
| `MONITORING_PORT`                  | `80`                 | CoreMedia Monitoring Port                                       |
| `MONITORING_API_VERSION`           | `2`                  | CoreMedia Monitoring API Version                                |
| `AWS_REGION`                       | `us-east-1`          | AWS Region                                                      |
| `AWS_ENVIRONMENT`                  | `development`        | AWS Environment                                                 |
| `INTERVAL`                         | `40`                 | run interval for the scheduler                                  |
| `RUN_DELAY`                        | `10`                 | delay for the first run                                         |

