Coremedia Monitoring
====================

Das Coremedia Monitoring basiert auf einem Set von mehreren Dockercontainern, welche die genutzten Services kappseln.

Der Einstaz von Docker ist nicht zwingend notwendig, wird aber in diesem Kontext genutzt um eine dynamische Entwicklung zu fördern.

Ziel ist ein funktionierendes Monitoring-System, welches auf jedem System ausgerollt werden kann.


# Status

Work-in-Progress


# Docker Compose

Im Verzeichniss `environments` befinden sich wetere Verzeichnisse, welche unterschiedliche Deploymentarten realisieren helfen.

 * `aio` bietet eine All-In-One Lösung, die alle Komponenten auf ein System zur Verfügung stellen kann.
  Diese kann idealerweise auf einem dezidiertem Server oder einem Notebook installiert werden und bietet die geringsten Einstiegshürden
 * `aws` bündelt ausschließlich Services zur Visualisierung der Monitoring Ergebnisse und bietet ein aktuelles **Grafana**  und **Icinga2**
 * `customer` beinhaltet alle Services, die zur Datenerhebung benutzt werden. Diese Daten werden anschließend an einen definierten Endpunkt
 (z.B. ein Setup, welches die `aws` Komponenten beinhaltet) reportet.

In diesen Unterverzeichnissen befindet sich jeweils eine `docker-compose` Datei, welches die benötigten Container verwaltet.

Um den Startvorgang zu beschleunigen, werden pre-compiled Container von [Docker Hub](https://hub.docker.com/r/bodsch/) benutzt.
Die einzelnen Container und deren Funktion sind [hier](./docker-container.md) beschrieben.



## Voraussetzung

In jedem Fall ist eine funktionierende DNS Auflösung sehr, sehr (sehr^10) hilfreich!

Der Zugriff auf die RMI Ports der Tomcats (xxx99) sollte gewährleistet sein.

Sollten `mysql` und `mongodb` ebenfalls ins Monitoring aufgenommen werden, müssen deren Ports ebenfalls erreichbar sein.

**Hinweis** Das Überwachen der `mysql` ist aktuell noch in einem sehr frühen Stadium, kann also zu Problemen führen!


[Installation](./installation.md)

[API](./api.md)

[JMX](./jmx.md)

[Configuration](./configuration.md)

[Docker Container](./docker-container.md)

[Operation](./operations.md)

[Service Discovery](./service-discovery.md)

[Screenshots](./screenshots.md)







