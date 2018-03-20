

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
