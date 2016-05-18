{
  "type" : "read",
  "mbean" : "com.coremedia:application=coremedia,type=Server",
  "attribute" : [
    "RunLevel",
    "ResourceCacheHits",
    "ResourceCacheEvicts",
    "ResourceCacheEntries",
    "ResourceCacheInterval",
    "ResourceCacheSize",
    "RepositorySequenceNumber",
    "ConnectionCount",
    "RunLevel",
    "Uptime"
  ],
  "target" : { "url" : "service:jmx:rmi:///jndi/rmi://localhost:%PORT%/jmxrmi", }
}
