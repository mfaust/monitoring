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

    curl -X POST http://localhost/api/$hostname
      {"status":201,"message":"Host successful created"}
    curl -X POST http://localhost/api/$hostname/force
      {"status":201,"message":"Host successful created"}


# List

    curl http://localhost/api
      {"status":200,"hosts":[{"moebius-16-tomcat":{"status":"online","created":"2016-08-12 10:53:37"}}]}

    curl http://localhost:4567/$hostname
      {"status":200,"hosts":{"moebius-16-tomcat":{"status":"online","created":"2016-08-12 10:53:25"},
      "services":{"postgres":{"port":5432},"mongodb":{"port":28017},"solr-master":{"port":40099},
      "content-management-server":{"port":40199},"master-live-server":{"port":40299},"workflow-server":{"port":40399},
      "content-feeder":{"port":40499},"user-changes":{"port":40599},"elastic-worker":{"port":40699},
      "caefeeder-preview":{"port":40799},"caefeeder-live":{"port":40899},"cae-preview":{"port":40999},
      "studio":{"port":41099},"adobe-drive-server":{"port":41199},"sitemanager":{"port":41399},"cae-live-1":{"port":42199}}}}


# löschen

    curl -X DELETE http://localhost:4567/$hostname
      {"status":200,"message":"Host successful removed"}

Es wird die Lib `discover.rb` im `lib` Verzeichniss benötigt.


data-raiser
-----------

Sammelt die Messdaten der Hosts ein, die über den ReST-Service angelegt wurden.

Es wird ein Fork des Scriptes erstellt und die run() Funktion aller 15 Sekunden aufgerufen. (Verbesserungswürdig)

Es wird die Lib `jolokia-data-raiser.rb` im `lib` Verzeichniss benötigt.

Folgender Dateien sind hierbei involviert:

 - `discovery.json`
 - `cm-application.json`
 - `cm-service.json`

Diese 3 Dateien werden folgendermaßen zusammen geführt:

Im ersten Schritt werden die Daten der `discovery.json` mit denen von `cm-service.json` angereichert, so daß die Keys `application`, `description`
und - im Falle der Solr Instanzen - die zu monitorendenen `cores` integriert werden.
Hier bei hat `discovery.json` den Vorrang, so daß erkannte Ports nicht überschrieben werden.


Der daraus erfolgte Datensatz wird anschließend mit `cm-application.json` zusammen geführt.
Dazu wird versucht an hand des jeweiligen Servicenamens die dazu passenden Metriken aufzunehmen.
Ist ein Key `application` gesetzt, werden die Metriken aus diesem Block innerhalb der `cm-application.json` genutzt.
Dadurch ist es möglich dem Services `caefeeder-live` und `caefeeder-preview` einen gleichen Satz an Metriken zuzuweisen.
Für Solr-Instanzen können zusätzlich verschiedene Cores in das Monitoring aufgenommen werden.
Die gewünschten Cores werden in der `cm-service.json` konfiguriert.

Die obigen Schritte ergeben eine `mergedHostData.json`

Aus dieser Json Datei wird anschließend ein Bulk Check erstellt und als Datei `bulk_$PORT_$SERVICE.json` abgespeichert
Dadurch erhalten wir mit einem Request alle zu monitorenden Daten eines Services.
Nach dem der Bulk Check an den genutzten jolokia Services geschickt wurde, wird das gewünschte Ergebniss unter `bulk_$PORT.result`
gespeichert.





Output Plugins
--------------

Zur Zeit existiert nur ein Output Plugin für graphite.
Ein Plugin für telegraf muss noch entwickelt und getestet werden.



Die Messdaten können über die Lib `collected-plugin.rb` im `lib` Verzeichniss abgearbeitet werden.

