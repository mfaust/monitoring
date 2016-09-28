{
  "type" : "read",
  "mbean" : "com.coremedia:application=coremedia,type=Server",
  "attribute" : [
    "AppDesc",
    "RunLevel",
    "ResourceCacheHits",
    "ResourceCacheEvicts",
    "ResourceCacheEntries",
    "ResourceCacheInterval",
    "ResourceCacheSize",
    "RepositorySequenceNumber",
    "ConnectionCount",
    "Uptime"
  ],
  "target" : { "url" : "service:jmx:rmi:///jndi/rmi://localhost:%PORT%/jmxrmi", }
}
