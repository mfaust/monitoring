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
    "ConnectionCount",
    "Uptime"
  ],
  "target" : { "url" : "service:jmx:rmi:///jndi/rmi://localhost:%PORT%/jmxrmi", }
}
