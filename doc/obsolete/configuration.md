
# Configuration

## Description

All Configuration Files are in YAML Style.


## locations



## file

### *`cm-monitoring.yaml`*

Basiskonfiguration des Monitoringstacks.


### *`cm-service.yaml`*

Beinhaltet alle bekannten und zu monitorenden Services.

Alle Services werden als Liste ausgeführt und haben folgenden Aufbau:

```
  cae-live-1:
    description: CAE Live
    port: 42199
    cap_connection: true
    uapi_cache: true
    blob_cache: true
    application:
    - cae
    - caches
    - caches-ibm
    template: cae
```

Hier ist folgendes zu beachten:

| Paramerter       | Beschreibung |
| :---------       | :----------- |
| `cae-live-1`     | Servicename, der durch das Service Discovery ermittelt wird. Der Servicename wird ausserdem benutzt um ein Grafana Dashboard anzulegen. |
| `port`           | der RMI Port, unter denen die JMX-Anfragen gestellt werden. **ACHTUNG** Der Port wird durch das Service Discovery gesetzt! |
| `port_http`      | sollte der Server eine *IOR* oder einen *HTTP* Port anbieten, wird dieser hier angegeben. **ACHTUNG** Der Port wird durch das Service Discovery gesetzt! |
| `cap-connection` | wird auf `true` gesetzt, wenn dieser Service eine *Cap-Connection* besitzt |
| `uapi_cache`     | wird auf `true` gesetzt, wenn dieser Service ein *UAPI Cache* besitzt |
| `blob_cache`     | wird auf `true` gesetzt, wenn dieser Service ein *Blob Cache* besitzt |
| `ior`            | wird auf `true` gesetzt, wenn dieser Service eine *IOR* besitzt |
| `runlevel`       | wird auf `true` gesetzt, wenn dieser Service ein *Runlevel* besitzt (alle Contentserver) |
| `license`        | wird auf `true` gesetzt, wenn dieser Service eine *Lizenz* benötigt (alle Contentserver) |
| `application`    | Eine Liste mit Application mbeans. Diese Liste wird nach dem Service Discovery mit Daten aus `cm-application.yaml` zusammengeführt. |
| `template`       | Sollte eine Applikation gefunden werden, die vom standard CoreMedia Namensschema abweicht, kann ich ein alternatives Template angegeben werden. |

Die Paramerter `port_http`, `cap-connection`, `uapi_cache`, `blob_cache`, `ior`, `runlevel` und `license` werden zusätzlich für **Icinga** Checks benötigt.


Der Service `solr-master` (bzw. `solr-slave`) besitzt zudem eine zusätzliche Angabe für die zu überwachenden Cores:

```
  solr-master:
    description: Solr Master
    port: 40099
    cores:
    - live
    - preview
    - studio
    application:
    - solr

  solr-slave:
    description: Solr Slave
    port: 40099
    cores:
    - live
    - preview
    - studio
    application:
    - solr
```

Die Solr-Cores können beliebig erweitert werden. Im Beispiel wurden nur die Standardcores angegeben.


### *`cm-application.yaml`*

Beinhaltet alle bekannten mbeans und deren Attribute für die CoreMedia Services.
Diese werden mit den erkannten Services zusammengeführt und für das weitere Monitoring benutzt.

Der Aufbau ist einfach gehalten und entspricht folgenden Schema:

```
    tomcat:
      description: standard checks for all tomcats
      metrics:
      - description: Heap Memory Usage
        mbean: java.lang:type=Memory
      - description: Thread Count
        mbean: java.lang:type=Threading
        attribute: TotalStartedThreadCount,ThreadCount,DaemonThreadCount,PeakThreadCount
```

Dabei gibt es einige zusätzliche Servicesdefinitionen:

* `tomcat`
* `contentserver`
* `caches`

Während der Service `tomcat` mit allen Services (ausser `mysql`, `postgres`, `mongodb`) explizit zusammen geführt wird, werden die Services
`contentserver`, `solr`, und `caches` nur mit denjenigen zusammengeführt, die diese in der `cm-service.yaml` unter `application` angegeben haben.






