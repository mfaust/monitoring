# Monitoring

Das ist ein Meta-Verzeichniss, welches mehrere - durchaus voneinander abhängigen - Dockercontainern enthält.

Basis ist ein funktionierendes Monitoring-System, welches auf jedem System ausgerollt werden kann. 

Das System ist so modular wie möglich aufgebaut, allerdings momentan noch in einem Proof-of-Concept Status.

## Inhalt

 - docker-chefdk
 - docker-cm-monitoring
 - docker-dashing
 - docker-grafana
 - docker-graphite
 - docker-icinga2
 - docker-icingaweb2
 - docker-jolokia
 - docker-mysql

### docker-chefdk

Ziel ist es, einen Container zu bekommen, der eine Basisinstallation von chedk zur Verfügung stellt, die anderen Containern zur Verfügung gestellt werden kann.

### cocker-cm-monitoring

Soll alle Coremediaspezifika beinhalten. Vor allem Scripte für Icinga und Grafana.

### docker-dashing

[Dashing](http://dashing.io/) ist ein einfache Dashing-Framework, welches über [Widgets}(https://github.com/Shopify/dashing/wiki/Additional-Widgets) erweitert werden kann.
Das Dashing-Framework kann von verschiedenen Services Daten einsammeln und visualisieren.

### docker-grafana

[Grafana](http://grafana.org/) ist ein Web-UI um Grafen in Echtzeit darstellen zu können.

Es können verschiedene Storage-Backends ([graphite](http://graphite.readthedocs.org/en/latest/), [influxdb](https://influxdata.com/), [Elasticsearch](https://www.elastic.co/products/elasticsearch), [Cloudwatch](https://aws.amazon.com/de/cloudwatch/), [Prometeus](https://prometheus.io/), [OpenTSDB](http://opentsdb.net/) ) benutzt werden.

### docker-graphite

Graphite ist das hier genutzte Storage-Backend für Grafana.

**ACHTUNG** docker-graphite **muss** vom Docker-Host über Namen und Port zur Verfügung stehen!

### docker-icinga2

[Icinga2](https://www.icinga.org/products/icinga-2/) ist der Monitoring-Host, welches Host- und Servicechecks ausführt.

### docker-icingaweb2

Das [Webfrontend](https://www.icinga.org/products/screenshots/icinga-web-2/) für Icinga2

### docker-jolokia

jmx2json Bridge.
Mit [jolokia](https://jolokia.org/) hat man die Möglichkeiten, die MBeans eines Tomcats über JMX abzufragen und die Ergebnisse in json lesbar zu bekommen.

### docker-mysql

Storage-Backend für Icinga2

## Kommunikation & Beziehungen

Die Storage-Engines (mysql und graphite) sollten jeweils als erstes gestartet werden.
Die jeweiligen Frontends prüfen die Erreichbarkeit ihrer Backends und starten ggf. zeitversetzt. 

**Portüberschneidungen müssen beim Start der Dockercontainer berücksichtigt werden!**

### Ports
 - docker-mysql
      - serving: port 3306
      - use: lokales Filesystem für persistente Daten
 - docker-dashing
      - serving: 3030 (http://localhost:3030)
      - use: docker-icinga2: 5665
 - docker-grafana
      - serving: 3000 (http://localhost:3000)
      - (use: docker-graphite)
 - docker-graphite
      - serving: 8080 (http://localhost:8080)
      - serving: 2003
      - serving: 7002
 - docker-icinga2
      - serving: 5665
      - serving: 6666
      - use: docker-mysql: 3306
      - use: lokales Filesystem 
 - docker-icingaweb2
      - serving: 80 (http://localhost/icinga)
      - use: docker-mysql: 3306
      - use: Filesystem von docker-icinga2
 - docker-jolokia
      - serving: 8080 (http://localhost:8080/jolokia)

## langfristiges Ziel

Die Idee für ein langfristiges Ziel wäre ein sich selbst konfigurierendes Monitoringsystem.
Hier könnte der Einsatz von [consul](https://www.consul.io/) ein wichtige Schritt sein.


