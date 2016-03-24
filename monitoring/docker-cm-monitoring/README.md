# docker-cm-monitoring

Soll alle Coremediaspezifika beinhalten. Vor allem Scripte für Icinga, Grafana und Jolokia.

Beim start des Containers erhält man sofort eine Bash.

Man kann mehrere Hosts über einen Script-Aufruf zum Monitoring hinzufügen. Dabei wird versucht - an Hand eines statischen Portschemas - festzustellen, welche Services dort gestartet wurden.

    bash-4.3# add-host.sh --help

     scan Ports on Host for Application Monitoring

     Version 1.0.0 (24.03.2016)

     Usage:    add-host [-h] [-v]
              -h                 : Show this help
              -v                 : Prints out the Version
              -f|--force         : regeneration all Host-Data (default: no force)
              -H|--host          : Hostname or IP
              -P|--old-portstyle : old port style for service discovery

Unterhalb von `/var/cache/monitoring` wird ein Cacheverzeichniss generiert, welches für jeden Host entsprechende Informationen vorhält.


Die Applikationsmesspunkte werden über das Skript `jolokia.sh` abgerufen und als json in die jeweilgen Verzeichniss abgelegt.

    bash-4.3# jolokia.sh --help

     run checks against jolokia to get json results from JMX

     Version 2.20.0 (24.03.2016)

     Usage:    jolokia [-h] [-v]
              -h            : Show this help
              -v            : Prints out the Version
              -D|--daemon   : start in Daemon-Mode (default: no daemon)
              -i|--interval : in daemon Mode, you cant set the runtime intervall in seconds (default: 58sec)

`jolokia.sh` wertet alle - durch das obige Script - angelgten Hosts aus.muss also nicht mehr mehrmals gestartet werden.

Um die Daten in das Graphen-System zu bekommen, kann man anschließend noch `collectd` starten und das wars für den ersten Test schon.

## Graphen
Grafana lässt sich im Browser unter http://localhost:3000/ aufrufen.
In der Regel werden dort bereits 2 Coremedia spezifische Dashboards importiert:

   - [blueprint-box](]http://localhost:3000/dashboard/file/Blueprint.json)
   - [co7madv01.coremdia.com](http://localhost:3000/dashboard/file/co7madv01.json)


