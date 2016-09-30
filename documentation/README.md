Coremedia Monitoring
====================

Das Coremedia Monitoring basiert auf mehreren - durchaus voneinander abhängigen - Dockercontainer.

Ziel ist ein funktionierendes Monitoring-System, welches auf jedem System ausgerollt werden kann.


# Status

Work-in-Progress

# Docker Compose

Im Verzeichniss `docker-compose-monitoring` befindet sich ein entsprechendes Compose File für ein komplettes Monitoring Setup.

Es werden pre-compiled Container von [Docker Hub](https://hub.docker.com/r/bodsch/) benutzt, um möglichst den lokalen Compilevorgang zu reduzieren.

Zusätzlich wird ein weiterer Docker Container (`cm-monitoring`) eingebunden, der initial und bei jeder weiteren Änderung gebaut werden muß.


## Voraussetzung

In jedem Fall ist eine funktionierende DNS Auflösung sehr, sehr (sehr^10) hilfreich!

Der Zugriff auf die Ports xxx99 sollte gewährleistet sein.

Sollten `mysql` und `mongodb` ebenfalls ins Monitoring aufgenommen werden, müssen deren Ports ebenfalls erreichbar sein.

**Hinweis** Das Überwachen der `mysql` ist aktuell noch in einem sehr frühen Stadium, kann also zu Problemen führen!


## Vorbereitungen & benötigte Software

Wir benötigen eine Docker Engine

 - [Mac](https://docs.docker.com/engine/installation/mac/)
 - [Linux](https://docs.docker.com/engine/installation/linux/ubuntulinux/)
 - [Windows](https://docs.docker.com/engine/installation/windows/)

Und docker-compose:

 - [docker-compose](https://docs.docker.com/compose/install/)


## API

Wir haben versucht, möglichst alles über eine API aufrufbar zu bekommen:

| Aufruf | Beschreibung |
| ------ | ------------- |
| `curl http://localhost/api`                                | Zeigt alle dem Monitoring bekannten Hosts |
| `curl http://localhost/api/$name`                          | Zeigt Alle Informationen zum Host an |
| `curl -X POST http://localhost/api/$name`                  | Fügt einen Host zum Monitoring hinzu und erstellt eine Set von vor definierten Grafana Dashboards |
| `curl -X POST http://localhost/api/$name/force`            | Fügt einen Host zum Monitoring hinzu, löscht aber vorher alle Autodiscovery Daten und Dashboards |
| `curl -X DELETE http://localhost/api/$name`                | Löscht einen Host aus dem Monitoring, erhält aber die Grafana Dashboards |
| `curl -X DELETE http://localhost/api/$name/force`          | Löscht einen Host aus dem Monitoring, inkl. der Grafana Dashboards |
| `curl -X POST http://localhost/api/a/node/create/$name`    | Erstellt eine Annotation das der Hosts neu erstellt wurde |
| `curl -X POST http://localhost/api/a/node/destroy/$name`   | Erstellt eine Annotation das der Hosts gelöscht wurde |
| `curl -X POST http://localhost/api/a/loadtest/start/$name` | Erstellt eine Annotation für das starten eines Lasttests |
| `curl -X POST http://localhost/api/a/loadtest/stop/$name`  | Erstellt eine Annotation für das beenden eines Lasttests |
| `curl -X POST http://localhost/api/g/$names`               | Fügt ein Übersichtsdashboard für eine Gruppe von Hosts hinzu. Die Hostnames werden durch + verbunden. Die Hosts müssen dem Monitoring bereits hinzugefügt worden sein. |
| `curl -X POST http://localhost/api/g/$names/force`         | Fügt ein Übersichtsdashboard für eine Gruppe von Hosts hinzu, löscht vorher das Dashboard. Die Hostnames werden durch + verbunden. Die Hosts müssen dem Monitoring bereits hinzugefügt worden sein. |

## Eigene Anpassungen

Im Verzeichnis `~/devops/monitoring/docker-compose-monitoring/share` befinden sich alle Dateien, die beim Erstellen des `cm-monitoring` Containers in diesen hinein kopiert werden.

### Anpassung für die DNS Auflösung

Für die Anpassung der DNS Auflösung muß die Datei `resolv.conf` angepasst werden.

### Dashboards

Alle Dashboards, die automatisch hinzugefügt werden, befinden sich im Verzeichnis `~/devops/monitoring/docker-cm-monitoring/rootfs/usr/local/share/templates/grafana`

**Mein Vorschlag für größere Änderungen beim Kunden**

Kopiert das Verzeichnis `docker-cm-monitoring` (z.b. `docker-guj-monitoring`) und passt das `docker-compose.yml` File an.



## Weiterentwicklung

Das System befindet sich in Entwicklung.

Zum Bauen eigener Graphen und System Checks wird es bestimmt mal einen Workshop geben. :)






