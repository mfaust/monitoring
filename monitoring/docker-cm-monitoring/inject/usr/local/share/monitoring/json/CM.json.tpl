{
  "type" : "read",
  "mbean" : "Catalina:j2eeType=WebModule,J2EEApplication=none,J2EEServer=none,name=//localhost/manager",
  "attribute" : [
    "configFile"
  ],
  "target" : { "url" : "service:jmx:rmi:///jndi/rmi://localhost:%PORT%/jmxrmi", }
}
