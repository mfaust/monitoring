# CoreMedia Monitoring Toolbox

Die *CoreMedia Monitoring Toolbox* bündelt ein Set von Services um ein Monitoring von CoreMedia Applikationen zu ermöglichen.

Diese Monitoring arbeitet passiv und es werden - bis auf kleinere Ausnahmen - keinerlei Anpassungen am Zielsystem nötig.

Aktuell sind folgende Services im Monitoring integriert:

  - Langzeitgraphen mittels Grafana
  - Alarmierungen mit Icinga2
  - einfaches Dashboard mit Dashing
  - demonstration einer Bereitschaftsdokumentation mit Integration in das Webinterface von Icinga2

Alle im weiteren Verlauf erwähnten Meßpunkte werden durch eine *Service-Discovery* detektiert und dem Monitoring zur Verfügung gestellt.

Die Monitoring-Toolbox lässt sich über eine API manuell nutzen oder in einer CI Umgebung integrieren.

Über einen externen Service kann diese auch in einer dynamischen Cloudumgebung eingesetzt werden.


## CoreMedia Applikationen

Bei CoreMedia Applikationen lassen sich folgende Systmparameter überwachen:

  - Tomcat interne Speicher (Heap-Memory, Perm-Memory, Caches)
  - Contentserver Lizenzen (Gültigkeit und verbrauchte (concurrent / named) Lizenzen)
  - Runlevel der Contentserver
  - Sequenznummern von MLS & RLS und die entsprechende Differenz
  - Gültigkeit von CapConnections
  - Auslastung der UAPI Caches
  - Auslastung der Blob Caches
  - zu feedende Elemete der CAEFeeder
  - Genutzte Lightweight Session von Clients
  - Auslastung der CAE Caches
  - Auslastung der eCommerce Caches
  - Gültigkeit von SSL Zertifikaten und deren Ablaufdatum

## Datenbanken

Sollten die Ports von MySQL und MongoDB erreichbar sein erhält man zusätzlich weiter Monitoringdaten dieser Services.

## Betriebssystemdaten

Daten der Betriebssystemes können durch die Nutzung des `node_exporters` ausgelesen werden.

## Webserver

Wenn der Apache Webserver `mod_status` aktiviert hat, können die darüber zur Verfügung stehenden Daten in das Monitoring integriert werden.
Wenn im default vhost eine `vhosts.json` Datein vorhanden ist, dann werden alle dort integrierten VHosts in das Monitoring aufgenommen.


1. [Installation](./de/installation.md)

2. [Configuration](./de/konfiguration.md)

3. [API](./api.md)

4. [JMX](./jmx.md)

5. [Operation](./operations.md)

6. [Service Discovery](./service-discovery.md)

7. [Screenshots](./screenshots.md)
