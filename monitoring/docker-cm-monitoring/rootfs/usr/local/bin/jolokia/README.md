Tools fürs Monitoring
=====================

Hier bunkert ein Set von Ruby Scripten, welche im Monitoring Setup genutzt werden können.


monitoring-rest-service
-----------------------

Startet einen kleinen ReST Service, mit dessen Hilfe man einen Host in das Monitoring aufnehmen oder daraus entfernen kann.

Der ReST Service ersetzt in gänze das alte `add-host.sh` Script.

Er führt ein Auto Discovery von Tomcat Applikationen durch und 'errät' die Applikation hinter den entsprechenden Ports.

Standardmäßig läuft der Service auf Port ```4567```

# start

    ruby bin/monitoring-rest-service.rb

# Add Host

    curl -X POST http://localhost:4567/$hostname
    curl -X POST http://localhost:4567/$hostname/force

# List

    curl http://localhost:4567
    curl http://localhost:4567/$hostname

# löschen

    curl -X DELETE http://localhost:4567/$hostname


Es wird die Lib `discover.rb` im `lib` Verzeichniss benötigt.


data-raiser
-----------

Sammelt die Messdaten der Hosts ein, die über den ReST-Service angelegt wurden.

Es wird ein Fork des Scriptes erstellt und die run() Funktion aller 15 Sekunden aufgerufen. (Verbesserungswürdig)

Es wird die Lib `jolokia-data-raiser.rb` im `lib` Verzeichniss benötigt.


Output Plugins
--------------

Zur Zeit existiert nur ein Output Plugin für graphite.
Ein Plugin für telegraf muss noch entwickelt und getestet werden.



Die Messdaten können über die Lib `collected-plugin.rb` im `lib` Verzeichniss abgearbeitet werden.

