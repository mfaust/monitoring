# JMX - Base Measurement Points for ALL Content Servers

| mbeans                                    | attribute                | description                                                         |
| :-----------------------------------------| :----------------------- | :------------------------------------------------------------------ |
| `com.coremedia:type=Server,application=*` | RunLevel                 | The current run level of the Content Server (*offline*, *online*, *maintenance*, *administration*) |
|                                           | Uptime                   | Uptime of the server (in ms)                                        |
|                                           | ResourceCacheHits        | Number of cache hits in `ResourceCacheInterval`                     |
|                                           | ResourceCacheEvicts      | Number of cache evicts in `ResourceCacheInterval`                   |
|                                           | ResourceCacheEntries     | Number of resources entered into the resource cache in the last `ResourceCacheInterval` |
|                                           | ResourceCacheInterval    | Interval in seconds after which the computation of the cache statistics starts again |
|                                           | ResourceCacheSize        | The current cache size (in resources)                               |
|                                           | RepositorySequenceNumber | The sequence number of the latest successful repository transaction |
|                                           | ConnectionCount          |                                                                     |

Connection Pool for DBA Connections
(**TODO, JMX description available**)

| mbeans                                                       | attribute            | description       |
| :----------------------------------------------------------- | :------------------- | :---------------- |
| `com.coremedia:type=Store,bean=ConnectionPool,application=*` | BusyConnections      |                   |
|                                                              | OpenConnections      |                   |
|                                                              | IdleConnections      |                   |
|                                                              | MaxConnections       |                   |
|                                                              | MinConnections       |                   |


(**TODO, JMX description available**)

| mbeans                                                  | attribute         | description       |
| :------------------------------------------------------ | :---------------- | :---------------- |
| `com.coremedia:type=Store,bean=QueryPool,application=*` | IdleExecutors     |                   |
|                                                         | RunningExecutors  |                   |
|                                                         | WaitingQueries    |                   |
|                                                         | MaxQueries        |                   |

