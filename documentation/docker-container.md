Docker Container
================

## nginx

Stellt einen Webserver zur Verfügung, unter dem alle Services einfach über eine Webseite erreichbar sind.

Die Startseite lässt sich im lokalen Browser unter [localhost](http://localhost) erreichen.


## grafana

[Grafana](http://grafana.org/) ist ein Web-UI um Grafen in Echtzeit darstellen zu können.

Es können verschiedene Storage-Backends ([graphite](http://graphite.readthedocs.org/en/latest/), [influxdb](https://influxdata.com/),
[Elasticsearch](https://www.elastic.co/products/elasticsearch), [Cloudwatch](https://aws.amazon.com/de/cloudwatch/),
[Prometeus](https://prometheus.io/), [OpenTSDB](http://opentsdb.net/) ) benutzt werden.

In diesem Meta-Package wird ausschließlich `graphite` genutzt.

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

Beinhaltet die REST-API um die Coremedia Services in das Monitoring aufzunehmen.

## cm-collectd

Ein Container, welcher die Daten zu einer Time-Series Datenbank weiterleitet.

## cm-data-collector

Ein Service, welcher in einem (konfigurierbaren) Interval die Messdaten erhebt.

## cm-external-discover

TBD

## cm-grafana-client

Ein Service, welcher mit dem Grafana Service kommuniziert und die entsprechenden Dashboards verwaltet.

## cm-graphite-client

Ein Service um Annotations in Grafana zu ermöglichen.

## cm-icinga-client

Ein Service für einen Icinga Satellite, welcher Host- und Servicechecks ausführt.

## cm-service-discover

Der Service, welcher das Coremedia Service Discovery vornimmt und feststellt, welcher Service in welchem Tomcat deployed wurde.

## Schematischer Aufbau
![schema](assets/cm-grafana.png "Schematischer Aufbau und Kommunikationsbeziehung")



## Nutzung

Mit Hilfe von `docker-compose` wir der gesammte Stack so gestartet, dass alle Abhängigkeiten aufgelöst werden.

Services, die von einander abhängig sind (z.B. eine Datenbank) legen entsprechende Wartezeit ein und prüfen deren Verfügbarkeit.


### Beispiele

TBD


## Start

TODO

    cd ~
    git clone -b docker git@github.com:CoreMedia/devops.git ~/monitoring/
    cd ~/monitoring/monitoring/docker-compose-monitoring
    docker-compose build
    docker-compose up -d

Nach dem erfolgreichen Start, kann über die Kommandozeile der zu monitorende Host hinzugefügt werden:

Das Script versicht ein auto-discovery durchzuführen um festzustellen, welche Anwendung auf den jeweiligen Port läuft und fügt anschließend Standardtemplates für grafana und icinga2 hinzu.

## Stop

    cd ~/monitoring/monitoring/docker-compose-monitoring
    docker-compose down

## persistente Daten

Im Verzeichniss `docker-compose-monitoring` wird ein `data` Verzeichniss erstellt, in dem alle Daten der Container abgelegt werden.

Das betrifft die `mysql`, `graphite` und `monitoring`.

Wenn diese nicht mehr benötigt werden, können diese entfernt werden.


## Bei Problemen

Man kann sich in alle Container einklinken und zusehen, was diese so treiben. Um sich mit dem `cm-monitoring` Container  zu verbinden reicht ein

    docker-compose exec cm-monitoring /bin/sh


