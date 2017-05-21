

## Eigene Anpassungen

**OBSOLETE**

must be rewrite!

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



