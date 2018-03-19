# JMX - Standard Tomcat

Standard Tomcat Mbeans findet man unterhalb von `java.lang`.


- `Memory`
    * `HeapMemoryUsage`
    * `NonHeapMemoryUsage`

- `Threading`
    * `TotalStartedThreadCount`
    * `ThreadCount`
    * `DaemonThreadCount`
    * `PeakThreadCount`

- `ClassLoading`
    * `TotalLoadedClassCount`
    * `LoadedClassCount`
    * `UnloadedClassCount`

- `GarbageCollector,name=ParNew`
    * `CollectionCount`
    * `CollectionTime`
    * `LastGcInfo`
        - `GcThreadCount`
        - `duration`
        - `endTime`
        - `startTime`

- `GarbageCollector,name=ConcurrentMarkSweep`
    * `CollectionCount`
    * `CollectionTime`
    * `LastGcInfo`
        - `GcThreadCount`
        - `duration`
        - `endTime`
        - `startTime`

Weiterführende mbeans findet man unterhalb von `Catalina`

- `Executor,name=tomcatThreadPool`
    * `activeCount`
    * `completedTaskCount`
    * `corePoolSize`
    * `poolSize`
    * `queueSize`
    * `maxQueueSize`

