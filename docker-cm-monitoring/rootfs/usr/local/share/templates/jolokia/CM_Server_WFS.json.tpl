{
  "type" : "read",
  "mbean" : "com.coremedia:application=workflow,type=Server",
  "attribute" : [
    "AppDesc"
  ],
  "target" : { "url" : "service:jmx:rmi:///jndi/rmi://localhost:%PORT%/jmxrmi", }
}
