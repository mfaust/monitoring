[
  {
    "type" : "read",
    "mbean" : "solr/%SHARD%:type=/replication,id=org.apache.solr.handler.ReplicationHandler",
    "attribute" : [
      "errors",
      "isMaster",
      "isSlave",
      "requests",
      "medianRequestTime",
      "indexVersion",
      "indexSize",
      "generation"
    ],
    "target" : { "url" : "service:jmx:rmi:///jndi/rmi://localhost:%PORT%/jmxrmi", }
  },
  {
    "type" : "read",
    "mbean" : "solr/%SHARD%:type=queryResultCache,id=org.apache.solr.search.LRUCache",
    "attribute" : [
      "cumulative_evictions",
      "cumulative_hitratio",
      "cumulative_hits",
      "cumulative_inserts",
      "cumulative_lookups",
      "description",
      "evictions",
      "hitratio",
      "hits",
      "inserts",
      "lookups",
      "size",
      "warmupTime"
    ],
    "target" : { "url" : "service:jmx:rmi:///jndi/rmi://localhost:%PORT%/jmxrmi", }
  }
]
