# docker-cm-monitoring

Soll alle Coremediaspezifika beinhalten. Vor allem Scripte für Icinga, Grafana und Jolokia.

Beim start des Containers erhält man sofort eine Bash.

    Welcome to CoreMedia Monitoring Project!

    This container holds many tools to handle some monitoring special things.

    Try the following
     -> add-host.sh --host blueprint-box                          to add Host 'blueprint-box' to monitoring
     -> add-host.sh --host co7madv01.coremedia.com --force        to force add Host 'co7madv01.coremedia.com' to monitoring (delete all old datas)

Man kann mehrere Hosts über einen Script-Aufruf zum Monitoring hinzufügen. Dabei wird versucht - an Hand eines festen Portschemas - festzustellen, welche Services dort gestartet wurden.

    bash-4.3# add-host.sh --help


    scan Ports on Host for Application Monitoring

     Version 2.1.1 (24.05.2016)

    Usage:    add-host [-h] [-v]
              -h         : Show this help
              -v         : Prints out the Version
              -f|--force : regeneration all Host-Data (default: no force)
              -H|--host  : Hostname or IP

Unterhalb von `/var/cache/monitoring` wird ein Cacheverzeichniss generiert, welches für jeden Host entsprechende Informationen vorhält.

Beim starten des Containers werden 2 Jobs automatisch gestartet:
   - jolokia.sh
   - collectd
Diese kümmern sich darum, dass die Monitoringdaten kontinuierlich eingesammelt und zu den Monitoring Systemen übertragen werden.


## Graphen
Grafana lässt sich im Browser unter http://localhost:3000/ aufrufen.

Mit dem obigen `add-host.sh` Script werden für jeden Host ein Set an Dashboard angelegt:

   - [Dashboard](]http://localhost:3000/dashboard)
