# JMX Beans

## Beschreibung

Die Beschreibung der JMX Beans finden Sie in der Dokumentation (siehe entsprechende Links) oder mit dem CoreMedia Tool `jmxdump`.

Beispiel
```bash
HOSTNAME=monitoring-16-01.coremedia.vm

cm \
  jmxdump \
  --url service:jmx:rmi://${HOSTNAME}:40198/jndi/rmi://${HOSTNAME}:40199/jmxrmi \
  -b com.coremedia:*type=Server* \
  -v
```

Alle verwendeten JMX Beans werden in der Konfigurationsdatei `cm-application.yml` aufgeführt (siehe auch unter [Konfiguration](./konfiguration.md))


## Tomcat Standard Checks

[tomcats](jmx/tomcat.md)


## Coremedia JMX Beans


| Type                           | CMS | MLS | RLS | WFS | CAE | Studio | Elastic-Worker | User-Changes | Content-Feeder | CAE-Feeder | Adobe-Drive |
| :----------------------------- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| CapConnection                  |    |    |    | x  | x  | x | x | x |   |   | x |
| Server                         | x  | x  | x  | x  |    |   |   |   |   |   |   |
| Store (Connection-, QueryPool) | x  | x  | x  |    |    |   |   |   |   |   |   |
| Statistics                     | x  | x  | x  |    |    |   |   |   |   |   |   |
| WFS Statistics                 |    |    |    | x  |    |   |   |   |   |   |   |
| Cache                          |    |    |    |    | x  |   |   |   |   |   |   |
| Replicator                     |    |    | x  |    |    |   |   |   |   |   |   |
| Feeder                         |    |    |    |    |    |   |   |   | x |   |   |
| ContentDependencyInvalidator   |    |    |    |    |    |   |   |   |   | x |   |
| ProactiveEngine                |    |    |    |    |    |   |   |   |   | x |   |
| Health                         |    |    |    |    |    |   |   |   |   | x |   |








### Attribute, Schwellenwerte und Beschreibung



[Base Measurement Points for ALL Content Servers](https://documentation.coremedia.com/dxp8/7.5.42-10/manuals/contentserver-en/webhelp/content/ManagedProperties.html)

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


(**TODO, JMX description available**)

| mbeans                                           | attribute                     | description                             |
| :----------------------------------------------- | :---------------------------- | :-------------------------------------- |
| `com.coremedia:type=CapConnection,application=*` | BlobCacheSize                 | max. Größe des Blobcaches               |
|                                                  | BlobCacheLevel                | belegte Daten                           |
|                                                  | BlobCacheFaults               |                                         |
|                                                  | HeapCacheSize                 | Größe des UAPI Caches                   |
|                                                  | HeapCacheLevel                |                                         |
|                                                  | HeapCacheFaults               |                                         |
|                                                  | NumberOfSUSessions            | Anzahl der aktiven Lightweight Sessions |


[Analyzing the Replicator State](https://documentation.coremedia.com/dxp8/7.5.42-10/manuals/contentserver-en/webhelp/content/AnalyzingtheReplicatorState.html)
[Managed Properties](https://documentation.coremedia.com/dxp8/7.5.42-10/manuals/contentserver-en/webhelp/content/ManagedProperties.html)
(**TODO, JMX description available**)

| mbeans                                        | attribute                      | description       |
| :-------------------------------------------- | :----------------------------- | :---------------- |
| `com.coremedia:type=Replicator,application=*` | ConnectionUp                   |                   |
|                                               | ControllerState                |                   |
|                                               | Enabled                        |                   |
|                                               | PipelineUp                     |                   |
|                                               | IncomingCount                  |                   |
|                                               | CompletedCount                 |                   |
|                                               | UncompletedCount               |                   |
|                                               | LatestCompletedSequenceNumber  |                   |
|                                               | LatestCompletedArrival         |                   |
|                                               | LatestCompletionDuration       |                   |
|                                               | LatestIncomingSequenceNumber   |                   |
|                                               | LatestIncomingArrival          |                   |


[CAE Feeder](https://documentation.coremedia.com/dxp8/7.5.42-10/manuals/search-en/webhelp/content/CAEFeederJMX.html)
(**TODO, JMX description available**)

| mbeans                                             | attribute                | description       |
| :------------------------------------------------- | :----------------------- | :---------------- |
| `com.coremedia:type=ProactiveEngine,application=*` | KeysCount                |                   |
|                                                    | ValuesCount              |                   |
|                                                    | InvalidationCount        |                   |
|                                                    | SendSuccessTimeLatest    |                   |
|                                                    | PurgeTimeLatest          |                   |
|                                                    | HeartBeat                |                   |
|                                                    | QueueCapacity            |                   |
|                                                    | QueueMaxSize             |                   |
|                                                    | QueueProcessedPerSecond  |                   |


(**TODO, JMX description available**)

| mbeans                                                | attribute                     | description       |
| :---------------------------------------------------- | :---------------------------- | :---------------- |
| `com.coremedia:type=ContentDependencyInvalidator,application=*` | -           | -                 |


[Health Manager](https://releases.coremedia.com/dxp8/7.5.42-10/distribution/apidocs/com/coremedia/cap/persistentcache/proactive/HealthManager.html)
(**TODO, JMX description available**)

| mbeans                                        | attribute                     | description       |
| :-------------------------------------------- | :---------------------------- | :---------------- |
| `com.coremedia:type=Health,application=*`     | -                             | -                 |


(**TODO, JMX description available**)

| mbeans                                                            | attribute                     | description       |
| :---------------------------------------------------------------- | :---------------------------- | :---------------- |
| `com.coremedia:type=Cache.Classes,CacheClass=\"*\",application=*` | Updated                       |                   |
|                                                                   | Evaluated                     |                   |
|                                                                   | Evicted                       |                   |
|                                                                   | EvictionRate                  |                   |
|                                                                   | Removed                       |                   |
|                                                                   | AverageEvaluationTime         |                   |
|                                                                   | RemovalRate                   |                   |
|                                                                   | Utilization                   |                   |
|                                                                   | Capacity                      |                   |
|                                                                   | InsertionRate                 |                   |
|                                                                   | Level                         |                   |
|                                                                   | Inserted                      |                   |
|                                                                   | MissRate                      |                   |

[Content Feeder](https://documentation.coremedia.com/dxp8/7.5.42-10/manuals/search-en/webhelp/content/ContentFeederJMX.html)
(**TODO, JMX description available**)

| mbeans                                    | attribute                     | description       |
| :-----------------------------------------| :---------------------------- | :---------------- |
| `com.coremedia:type=Feeder,application=*` | State                         |                   |
|                                           | Uptime                        |                   |
|                                           | CurrentPendingDocuments       |                   |
|                                           | IndexAverageBatchSendingTime  |                   |
|                                           | IndexDocuments                |                   |
|                                           | IndexContentDocuments         |                   |
|                                           | IndexBytes                    |                   |
|                                           | PendingEvents                 |                   |
|                                           | PendingFolders                |                   |

[Will not be documented](https://documentation.coremedia.com/dxp8/7.5.42-10/manuals/contentserver-en/webhelp/content/ManagedProperties.html)

| mbeans                                                | attribute                     | description       |
| :---------------------------------------------------- | :---------------------------- | :---------------- |
| `com.coremedia:type=Statistics,module=BlobStore,pool=BlobStoreMethods,application=*` | -  | -             |

| mbeans                                                | attribute                     | description       |
| :---------------------------------------------------- | :---------------------------- | :---------------- |
| `com.coremedia:type=Statistics,module=StoreStatistics,pool=Job Result,application=*` | -  | -             |

| mbeans                                                | attribute                     | description       |
| :---------------------------------------------------- | :---------------------------- | :---------------- |
| `com.coremedia:type=Statistics,module=RepositoryStatistics,pool=Resource,application=*` | -  | -          |

| mbeans                                                | attribute                     | description       |
| :---------------------------------------------------- | :---------------------------- | :---------------- |
| `com.coremedia:type=Statistics,module=ResourceCacheStatistics,pool=ResourceCache,application=*` | -  | -  |

| mbeans                                                | attribute                     | description       |
| :---------------------------------------------------- | :---------------------------- | :---------------- |
| `com.coremedia:type=Statistics,module=TextStore,pool=TextStoreMethods,application=*` | -  | -             |


## Named Services


### Content-Management-Server

| mbeans                                                | attribute                     | description       |
| :---------------------------------------------------- | :---------------------------- | :---------------- |
| -                                                     | -                             | -                 |

### Master Live Server

| mbeans                                                | attribute                     | description       |
| :---------------------------------------------------- | :---------------------------- | :---------------- |
| -                                                     | -                             | -                 |

### Replication Live Server

| mbeans                                                | attribute                     | description       |
| :---------------------------------------------------- | :---------------------------- | :---------------- |
| -                                                     | -                             | -                 |

### Workflow Server

| mbeans                                                | attribute                     | description       |
| :---------------------------------------------------- | :---------------------------- | :---------------- |
| -                                                     | -                             | -                 |

### Elastic Worker

| mbeans                                                | attribute                     | description       |
| :---------------------------------------------------- | :---------------------------- | :---------------- |
| -                                                     | -                             | -                 |

### User Changes

| mbeans                                                | attribute                     | description       |
| :---------------------------------------------------- | :---------------------------- | :---------------- |
| -                                                     | -                             | -                 |

### Content Feeder

| mbeans                                                | attribute                     | description       |
| :---------------------------------------------------- | :---------------------------- | :---------------- |
| -                                                     | -                             | -                 |

### CAE Feeder

| mbeans                                                | attribute                     | description       |
| :---------------------------------------------------- | :---------------------------- | :---------------- |
| -                                                     | -                             | -                 |

### Adobe Drive

| mbeans                                                | attribute                     | description       |
| :---------------------------------------------------- | :---------------------------- | :---------------- |
| -                                                     | -                             | -                 |

### Sitemanager

| mbeans                                                | attribute                     | description       |
| :---------------------------------------------------- | :---------------------------- | :---------------- |
| -                                                     | -                             | -                 |

### CAE

| mbeans                                                | attribute                     | description       |
| :---------------------------------------------------- | :---------------------------- | :---------------- |
| -                                                     | -                             | -                 |

### Studio

| mbeans                                                | attribute                     | description       |
| :---------------------------------------------------- | :---------------------------- | :---------------- |
| -                                                     | -                             | -                 |


### Solr

| mbeans                                                | attribute                     | description       |
| :---------------------------------------------------- | :---------------------------- | :---------------- |
| -                                                     | -                             | -                 |
