Coremedia Monitoring
====================

Das Coremedia Monitoring basiert auf mehreren - durchaus voneinander abhängigen - Dockercontainer.

Ziel ist ein funktionierendes Monitoring-System, welches auf jedem System ausgerollt werden kann.


# Service Discovery



```
[
  {
    "type": "read",
    "mbean": "java.lang:type=Runtime",
    "attribute": [
      "ClassPath"
    ],
    "target": {
      "url": "service:jmx:rmi:///jndi/rmi://monitoring-16-01:42199/jmxrmi"
    },
    "config": {
      "ignoreErrors": true,
      "ifModifiedSince": true,
      "canonicalNaming": true
    }
  },
  {
    "type": "read",
    "mbean": "Catalina:type=Manager,context=*,host=*",
    "target": {
      "url": "service:jmx:rmi:///jndi/rmi://monitoring-16-01:42199/jmxrmi"
    },
    "config": {
      "ignoreErrors": true,
      "ifModifiedSince": true,
      "canonicalNaming": true
    }
  },
  {
    "type": "read",
    "mbean": "Catalina:type=Engine",
    "attribute": [
      "baseDir",
      "jvmRoute"
    ],
    "target": {
      "url": "service:jmx:rmi:///jndi/rmi://monitoring-16-01:42199/jmxrmi"
    },
    "config": {
      "ignoreErrors": true,
      "ifModifiedSince": true,
      "canonicalNaming": true
    }
  }
]
```

# results

## 7.0

## 7.1

## 7.5

## 17xx

```
[
  {
    "request": {
      "mbean": "java.lang:type=Runtime",
      "attribute": "ClassPath",
      "type": "read",
      "target": {
        "url": "service:jmx:rmi:///jndi/rmi://monitoring-16-01:42199/jmxrmi"
      }
    },
    "value": {
      "ClassPath": "/opt/coremedia/cae-live-1/current/bin/bootstrap.jar:/opt/coremedia/cae-live-1/current/bin/tomcat-juli.jar"
    },
    "timestamp": 1483365782,
    "status": 200
  },
  {
    "request": {
      "mbean": "Catalina:context=*,host=*,type=Manager",
      "type": "read",
      "target": {
        "url": "service:jmx:rmi:///jndi/rmi://monitoring-16-01:42199/jmxrmi"
      }
    },
    "value": {
      "Catalina:context=/blueprint,host=localhost,type=Manager": {
        "sessionAttributeValueClassNameFilter": null,
        "modelerType": "org.apache.catalina.session.StandardManager",
        "sessionIdLength": -1,
        "warnOnSessionAttributeFilterFailure": false,
        "className": "org.apache.catalina.session.StandardManager",
        "secureRandomAlgorithm": "SHA1PRNG",
        "maxInactiveInterval": 3600,
        "secureRandomClass": null,
        "sessionAverageAliveTime": 0,
        "rejectedSessions": 0,
        "processExpiresFrequency": 6,
        "stateName": "STARTED",
        "duplicates": 0,
        "distributable": false,
        "maxActiveSessions": -1,
        "sessionMaxAliveTime": 0,
        "processingTime": 4,
        "pathname": "SESSIONS.ser",
        "sessionExpireRate": 0,
        "sessionAttributeNameFilter": null,
        "activeSessions": 0,
        "sessionCreateRate": 0,
        "name": "StandardManager",
        "secureRandomProvider": null,
        "jvmRoute": "cae-live-1",
        "expiredSessions": 0,
        "maxActive": 0,
        "sessionCounter": 0
      }
    },
    "timestamp": 1483365782,
    "status": 200
  },
  {
    "request": {
      "mbean": "Catalina:type=Engine",
      "attribute": [
        "baseDir",
        "jvmRoute"
      ],
      "type": "read",
      "target": {
        "url": "service:jmx:rmi:///jndi/rmi://monitoring-16-01:42199/jmxrmi"
      }
    },
    "value": {
      "baseDir": "/opt/coremedia/cae-live-1/current",
      "jvmRoute": "cae-live-1"
    },
    "timestamp": 1483365782,
    "status": 200
  }
]

```

