
# REST API

Wir haben versucht, möglichst alles über eine einfach API aufrufbar zu bekommen.


## Description

Our Monitoring provides an simplyfied API to create and destroy Nodes for Monitoring.
This API helps also to create Annotations and give back Informations about all known Hosts

## Examples

## Help

```
    curl \
      http://localhost/api/v2/help
```

---

## Nodes

### add Node to Monitoring

Das hinzufügen wird über einen `POST` Request ermöglicht. Hierbei kann über `--data` json formatierte Parameter mitgegeben werden:

Aktuell funktionieren folgende Paramaeter:

| Parameter    | Typ     | default | Beschreibung |
| :---------   | :-----: | :-----: | :----------- |
| `force`      | bool    | false   | wenn `true` gesetzt ist, werden alle vorher gefundenen Informationen über die Node gelöscht |
| `tags`       | Array   | []      | Eine Liste von Tags, die an die Node in Grafana gehängt werden |
| `config`     | Hash    | {}      | Ein Hash für das direkte schreiben einer Konfiguration |

Unterterhalb von `config` stehen weitere Parameter zur Verfügung:
                                                                                                                                                                                                        | Beispiel                                              |
| Parameter             | Typ     | default       | Beschreibung                                                                                                                                        | :-------                                              |
| :---------            | :-----: | :-----        | :-----------                                                                                                                                        | `"graphite-identifier": "development-system"`         |
| `graphite-identifier` | String  | `${HOSTNAME}` | Ändert den Identifier für die Kombination `graphite` / `grafana`                                                                                    |                                                       |
|                       |         |               | dadurch ist es möglich in einer sehr dynamischen Umgebung (z.B. Amazon Web Services) einen einheitlichen Identifier für das Graphensystem zu nutzen | `"ports": [50199,51099]`                              |
| `ports`               | Array   | []            | **ersetzt** den intern genutzten Portbereich                                                                                                        |                                                       |
|                       |         |               | hierdurch kann man gezielt individuelle Ports durch das Monitoring nutzen.                                                                          | `"display-name": "foo.bar.com"`                       |
| `display-name`        | String  | `${HOSTNAME}` | ändert den Anzeige Namen im Grafana.                                                                                                                |                                                       |
|                       |         |               | dadurch kann man individuelle Namen nutzen                                                                                                          | `"services": ["cae-live","content-managment-server"]` |
| `services`            | Array   | []            | **ergänzt** die Services, die durch die Service Discovery gefunden werden.                                                                          | |
|                       |         |               | dadurch ist es möglich den Server **vor** den Starten der Services in das Monitoring zu integrieren                                                 | |
|                       |         |               | bzw. einen Service mit langer Startzeit oder größeren Abhängigkeiten vorzugeben                                                                     | |


**Beispiel eines Parametersatzes**

    {
      "force": true,
      "tags": [
        "development",
        "git-0000000"
      ],
      "config": {
        "graphite-identifier": "development-system",
        "ports": [50199,51099],
        "display-name": "foo.bar.com",
        "services": ["cae-live","content-managment-server"]
      }
    }


#### kompletter Aufruf
```
    HOSTNAME=monitoring-16-01.coremedia.vm

    curl \
      --silent \
      --request POST \
      --data '{ "force": true }' \
      http://localhost/api/v2/host/${HOSTNAME} | \
      json_reformat

    {
      "request": {
        "force": true
      },
      "monitoring-16-01": {
        "grafana": {
          "status": 200,
          "message": "20 dashboards added",
          "dashboards": 20
        },
        "discovery": {
          "status": 200,
          "message": "Host successful created"
        }
      }
    }
```

### remove Node from Monitoring

Das löschen einer Node wird über ein `DELETE` ermöglicht.
Auch hier ist es möglich das löschen über `--data` Parameter feingranular zu steuern.

Aktuell funktionieren folgende Paramaeter:

| Parameter    | Typ     | default | Beschreibung |
| :---------   | :-----: | :-----: | :----------- |
| `annotation` | bool    | true    | setzt eine Annotation für das entfernen einer Node |


**Beispiel eines Parametersatzes**

     example:
     {
       "icinga": false,
       "grafana": false,
       "annotation": true
     }

#### kompletter Aufruf
```
    HOSTNAME=monitoring-16-01.coremedia.vm

    curl \
      --silent \
      --request DELETE \
      http://localhost/api/v2/host/${HOSTNAME} | \
      json_reformat
```

---

# give Information about Node

Informationen über die Nodes des Monitorings bekommt man über ein `GET` zurückgeliefert.
Hierbei gibt es 2 Möglichkeiten:

* ohne Parameter:
```
    HOSTNAME=monitoring-16-01.coremedia.vm

    curl \
      --silent \
      --request GET \
      http://localhost/api/v2/host | \
      json_reformat
```
* mit Parameter:
```
    HOSTNAME=monitoring-16-01.coremedia.vm

    curl \
      --silent \
      --request GET \
      http://localhost/api/v2/host/${HOSTNAME} | \
      json_reformat
```

---

# Grafana Annotations

Annotationen bieten eine Möglichkeit, Messpunkte in einem Graphen mit einem Ereignissen zu markieren bzw. anzureichern.

Zu diesem Zweck haben wir 4 Arten von üblichen Annotationen fest integriert:

* das erstellen einer Node (`create`)
* das entfernen einer Node (`destroy`)
* Lasttestest (`loadtest`)
* Deployments (`deployment`)

Zu jedem dieser Annotationen ist es möglich, über `--data` json formatierte Parameter dem REST Aufruf mitzugeben:

* **`create`**

```
    HOSTNAME=monitoring-16-01.coremedia.vm

    curl \
      --silent \
      --request POST \
      --data '{ "command": "create" }' \
      http://localhost/api/v2/annotation/${HOSTNAME} | \
      json_reformat
```

* **`destroy`**

```
    HOSTNAME=monitoring-16-01.coremedia.vm

    curl \
      --silent \
      --request POST \
      --data '{ "command": "destroy" }' \
      http://localhost/api/v2/annotation/${HOSTNAME} | \
      json_reformat
```

* **`loadtest`**

```
    HOSTNAME=monitoring-16-01.coremedia.vm

    curl \
      --silent \
      --request POST \
      --data '{ "command": "loadtest", "argument": "start" }' \
      http://localhost/api/v2/annotation/${HOSTNAME} | \
      json_reformat


    curl \
      --silent \
      --request POST \
      --data '{ "command": "loadtest", "argument": "stop" }' \
      http://localhost/api/v2/annotation/${HOSTNAME} | \
      json_reformat
```

* **`deployment`**

```
    HOSTNAME=monitoring-16-01.coremedia.vm

    curl \
      --silent \
      --request POST \
      --data '{ "command": "deployment", "message": "version 7.1.50", "tags": ["7.1.50"] }' \
      http://localhost/api/v2/annotation/${HOSTNAME} | \
      json_reformat
```

Für diese Annotation Typen wurden in den von CoreMedia mitgelieferten Templates entsprechende Anzeigemöglichkeiten geschaffen.
