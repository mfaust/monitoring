{
  "type" : "read",
  "mbean" : "com.coremedia:type=CapConnection,application=caefeeder",
  "attribute" : [
    "BlobCacheSize",
    "BlobCacheLevel",
    "BlobCacheFaults",
    "HeapCacheSize",
    "HeapCacheLevel",
    "HeapCacheFaults",
    "NumberOfSUSessions"
  ],
  "target" : { "url" : "service:jmx:rmi:///jndi/rmi://localhost:%PORT%/jmxrmi", }
}
