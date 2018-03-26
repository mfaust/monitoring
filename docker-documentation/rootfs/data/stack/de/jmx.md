# JMX Beans

## Beschreibung

Die Beschreibung der JMX Beans finden Sie in der Dokumentation (siehe entsprechende Links) oder mit dem CoreMedia Tool `jmxdump`.

Beispiel
```bash
HOSTNAME=monitoring-16-01.coremedia.vm

cm \
  jmxdump \
  --url service:jmx:rmi://${HOSTNAME}:40198/jndi/rmi://${HOSTNAME}:40199/jmxrmi \
  -b com.coremedia:*type=Server* \
  -v
```

Alle verwendeten JMX Beans werden in der Konfigurationsdatei `cm-application.yml` aufgeführt (siehe auch unter [Konfiguration](./konfiguration.md))



## Coremedia JMX Beans


| Type                           | CMS | MLS | RLS | WFS | CAE | Studio | Elastic-Worker | User-Changes | Content-Feeder | CAE-Feeder | Adobe-Drive |
| :----------------------------- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| CapConnection                  |    |    |    | x  | x  | x | x | x |   |   | x |
| Server                         | x  | x  | x  | x  |    |   |   |   |   |   |   |
| Store (Connection-, QueryPool) | x  | x  | x  |    |    |   |   |   |   |   |   |
| Statistics                     | x  | x  | x  |    |    |   |   |   |   |   |   |
| WFS Statistics                 |    |    |    | x  |    |   |   |   |   |   |   |
| Cache                          |    |    |    |    | x  |   |   |   |   |   |   |
| Replicator                     |    |    | x  |    |    |   |   |   |   |   |   |
| Feeder                         |    |    |    |    |    |   |   |   | x |   |   |
| ContentDependencyInvalidator   |    |    |    |    |    |   |   |   |   | x |   |
| ProactiveEngine                |    |    |    |    |    |   |   |   |   | x |   |
| Health                         |    |    |    |    |    |   |   |   |   | x |   |

<br>

- [Tomcats](./jmx/tomcat.md)
- [Solr](./jmx/solr.md)
- [CapConnection](./jmx/capconnection.md)
- [Caches](./jmx/caches.md)
- [Content Servers](./jmx/content-servers.md)
- [Replication Live Server](./jmx/replication-live-server.md)
- [Content Feeder](./jmx/content-feeder.md)
- [CAE Feeder](./jmx/caefeeder.md)
- [CAE](./jmx/cae)
