docker-compose-monitoring
=========================

Compose File für ein komplettes Monitoring Setup.

Es werden pre-compiled Container von [Docker Hub](https://hub.docker.com/r/bodsch/) benutzt um möglichst den lokalen Compilevorgang zu reduzieren.

Das Setup beinhaltet ein Set von mehreren Containern:

 - database
 - jolokia
 - memcached
 - nginx
 - graphite
 - grafana
 - icinga2-core
 - icingaweb2

Es muss zusätzlich noch der Docker Container ```docker-cm-monitoring``` gebaut und gestartet werden.


## nginx

Stellt einen Webserver zur Verfügung, unter dem alle Services einfach über eine Webseite erreichbar sind.

Die Startseite lässt sich im lokalen Browser unter [localhost](http://localhost) erreichen.


## grafana

[Grafana](http://grafana.org/) ist ein Web-UI um Grafen in Echtzeit darstellen zu können.

Es können verschiedene Storage-Backends ([graphite](http://graphite.readthedocs.org/en/latest/), [influxdb](https://influxdata.com/), [Elasticsearch](https://www.elastic.co/products/elasticsearch), [Cloudwatch](https://aws.amazon.com/de/cloudwatch/), [Prometeus](https://prometheus.io/), [OpenTSDB](http://opentsdb.net/) ) benutzt werden.

In diesem Meta-Package wird ausschließlich graphite genutzt.

Im lokalen Browser steht unter [grafana](http://localhost/grafana/) zur Verfügung.
Die Login Daten lauten:
 admin:admin


## graphite

Graphite ist das hier genutzte Storage-Backend für Grafana.


## icinga2-core

[Icinga2](https://www.icinga.org/products/icinga-2/) ist der Monitoring-Host, welches Host- und Servicechecks ausführt.


## icingaweb2

Das [Webfrontend](https://www.icinga.org/products/screenshots/icinga-web-2/) für Icinga2.

Im lokalen Browser steht unter [icingaweb2](http://localhost/icinga/) zur Verfügung.
Die Login Daten lauten:
 icinga:icinga


## jolokia

Eine jmx2json Bridge.

Mit [jolokia](https://jolokia.org/) hat man die Möglichkeiten, die MBeans eines Tomcats über JMX abzufragen und die Ergebnisse in json lesbar zu bekommen.


## database

Docker Container mit einer mySQL Datenbank.

Dient als Storage-Backend für Icinga2, Graphite, Grafana.


## cm-monitoring

Beinhaltet alle Coremediaspezifika. Vor allem Scripte für Icinga, Grafana und Jolokia.

In dem Container wird der zu monitorende Host in das System eingefügt.
Er sollte generell als letzter Container gestartet werden und in einer `screen` Session laufen, da nach dem beenden dieses Containers alle darin laufenden Jobs beendet werden.


## langfristiges Ziel

Die Idee für ein langfristiges Ziel wäre ein sich selbst konfigurierendes Monitoringsystem.
Hier könnte der Einsatz von [consul](https://www.consul.io/) ein wichtige Schritt sein.


## Schematischer Aufbau
![schema](schema.png "Schematischer aufbau und Kommunikationsbeziehung")


## Vorbereitungen & benötigte Software

Wir benötigen eine Docker Engine

 - [Mac](https://docs.docker.com/engine/installation/mac/)
 - [Linux](https://docs.docker.com/engine/installation/linux/ubuntulinux/)
 - [Windows](https://docs.docker.com/engine/installation/windows/)

Und docker-compose:

 - [docker-compose](https://docs.docker.com/compose/install/)


## Nutzung

Mit Hilfe von ```docker-compose``` wir der gesammte Stack so gestartet, dass alle Abhängigkeiten aufgelöst werden.

Services, die von einander abhängig sind (z.B. eine verfügbare Datenbank) legen entsprechende Wartezeit ein und prüfen deren Verfügbarkeit.


## Start

    git clone git@github.com:CoreMedia/devops.git
    cd devops
    git checkout docker
    cd monitoring/docker-compose-monitoring
    docker-compose up

    cd ../docker-cm-monitoring
    screen -S cm-mon
    make
    make run

Nach dem erfolgreichen Start, kann über die Kommandozeile der zu monitende Host hinzugefügt werden:

    add-host --host $name

Das Script versicht ein auto-discovery durchzuführen um festzustellen, welche Anwendung auf den jeweiligen Port läuft und fügt anschließend Standardtemplates für grafana und icinga2 hinzu.


## Weiterentwicklung

Das System befindet sich in Entwicklung.

Zum Bauen eigener Graphen und System Checks wird es bestimmt mal einen Workshop geben. :)






