{
  "type" : "read",
  "mbean" : "java.lang:type=Memory",
  "attribute" : [
    "HeapMemoryUsage",
    "NonHeapMemoryUsage"
  ],
  "target" : { "url" : "service:jmx:rmi:///jndi/rmi://localhost:%PORT%/jmxrmi", }
}
