Coremedia Monitoring
====================

Das Coremedia Monitoring basiert auf mehrere - durchaus voneinander abhängige - Dockercontainer.

Ziel ist ein funktionierendes Monitoring-System, welches auf jedem System ausgerollt werden kann.


# Status

Work-in-Progress

# Docker Compose

Im Verzeichniss `docker-compose-monitoring` befindet sich ein entsprechende Compose File für ein komplettes Monitoring Setup.

Es werden pre-compiled Container von [Docker Hub](https://hub.docker.com/r/bodsch/) benutzt um möglichst den lokalen Compilevorgang zu reduzieren.

Das Setup beinhaltet ein Set von mehreren Containern:

 - `database`
 - `jolokia`
 - `memcached`
 - `nginx`
 - `graphite`
 - `grafana`
 - `icinga2-core`
 - `icingaweb2`

Zusätzlich wird ein weiterer Docker Container (`cm-monitoring`) eingebunden, der initial und bei jeder weiteren Änderung gebaut werden muß.


## nginx

Stellt einen Webserver zur Verfügung, unter dem alle Services einfach über eine Webseite erreichbar sind.

Die Startseite lässt sich im lokalen Browser unter [localhost](http://localhost) erreichen.


## grafana

[Grafana](http://grafana.org/) ist ein Web-UI um Grafen in Echtzeit darstellen zu können.

Es können verschiedene Storage-Backends ([graphite](http://graphite.readthedocs.org/en/latest/), [influxdb](https://influxdata.com/), [Elasticsearch](https://www.elastic.co/products/elasticsearch), [Cloudwatch](https://aws.amazon.com/de/cloudwatch/), [Prometeus](https://prometheus.io/), [OpenTSDB](http://opentsdb.net/) ) benutzt werden.

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

Beinhaltet alle Coremediaspezifika. Vor allem Scripte für Icinga, Grafana und Jolokia.

In dem Container wird der zu monitorende Host in das System eingefügt.


## Schematischer Aufbau
![schema](assetts/cm-grafana.png "Schematischer Aufbau und Kommunikationsbeziehung")


## Vorraussetzung

In jedem Fall ist eine funktionierende DNS Auflösung sehr, sehr (sehr^10) hilfreich!


## Vorbereitungen & benötigte Software

Wir benötigen eine Docker Engine

 - [Mac](https://docs.docker.com/engine/installation/mac/)
 - [Linux](https://docs.docker.com/engine/installation/linux/ubuntulinux/)
 - [Windows](https://docs.docker.com/engine/installation/windows/)

Und docker-compose:

 - [docker-compose](https://docs.docker.com/compose/install/)


## Nutzung

Mit Hilfe von `docker-compose` wir der gesammte Stack so gestartet, dass alle Abhängigkeiten aufgelöst werden.

Services, die von einander abhängig sind (z.B. eine verfügbare Datenbank) legen entsprechende Wartezeit ein und prüfen deren Verfügbarkeit.


## Start

    cd ~
    git clone git@github.com:CoreMedia/devops.git
    cd devops
    git checkout docker
    cd monitoring/docker-compose-monitoring
    docker-compose build
    docker-compose up -d

Nach dem erfolgreichen Start, kann über die Kommandozeile der zu monitorende Host hinzugefügt werden:



Das Script versicht ein auto-discovery durchzuführen um festzustellen, welche Anwendung auf den jeweiligen Port läuft und fügt anschließend Standardtemplates für grafana und icinga2 hinzu.

## Stop

    cd ~
    cd ~/devops/monitoring/docker-compose-monitoring
    docker-compose down

## API

Wir haben versucht, möglichst alles über eine API aufrufbar zu bekommen:

| Aufruf | Beschreibung |
`curl http://localhost/api`                                | Zeigt alle dem Monitoring bekannten Hosts
`curl http://localhost/api/$name`                          | Zeigt Alle Informationen zum Host an
`curl -X POST http://localhost/api/$name`                  | Fügt einen Host zum Monitoring hinzu und erstellt eine Set von vor definierten Grafana Dashboards
`curl -X POST http://localhost/api/$name/force`            | Fügt einen Host zum Monitoring hinzu, löscht aber vorher alle Autodiscovery Daten und Dashboards
`curl -X DELETE http://localhost/api/$name`                | Löscht einen Host aus dem Monitoring, erhält aber die Grafana Dashboards
`curl -X DELETE http://localhost/api/$name/force`          | Löscht einen Host aus dem Monitoring, inkl. der Grafana Dashboards
`curl -X POST http://localhost/api/a/node/create/$name`    | Erstellt eine Annotation das der Hosts neu erstellt wurde
`curl -X POST http://localhost/api/a/node/destroy/$name`   | Erstellt eine Annotation das der Hosts gelöscht wurde
`curl -X POST http://localhost/api/a/loadtest/start/$name` | Erstellt eine Annotation für das starten eines Lasttests
`curl -X POST http://localhost/api/a/loadtest/stop/$name`  | Erstellt eine Annotation für das beenden eines Lasttests


## Eigene Anpassungen

Im Verzeichniss `~/devops/monitoring/docker-compose-monitoring/share` befinden sich alle Dateien, die beim erstellen des `cm-monitoring` Containers in diesen hinein kopiert werden.

### Anpassung für die DNS Auflösung

Für die Anpassung der DNS Auflösung muß die Datei `resolv.conf` angepasst werden.

### Dashboards

Alle Dashboards, die automatisch hinzugefügt werden, befinden sich im Verzeichniss `~/devops/monitoring/docker-cm-monitoring/rootfs/usr/local/share/templates/grafana`

**Mein Vorschlag für größere Änderungen beim Kunden**

Kopiert das Verzeichniss `docker-cm-monitoring` (z.b. `docker-guj-monitoring`) und passt das `docker-compose.yml` File an.



## Weiterentwicklung

Das System befindet sich in Entwicklung.

Zum Bauen eigener Graphen und System Checks wird es bestimmt mal einen Workshop geben. :)






