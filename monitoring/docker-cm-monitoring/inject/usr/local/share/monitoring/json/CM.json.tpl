{
  "type" : "read",
  "mbean" : "Catalina:j2eeType=WebModule,J2EEApplication=none,J2EEServer=none,name=//localhost/%TYPE%",
  "attribute" : [
    "docBase",
    "configFile",
    "baseName",
    "workDir",
    "path"
  ],
  "target" : { "url" : "service:jmx:rmi:///jndi/rmi://%HOST%:%PORT%/jmxrmi", }
}
