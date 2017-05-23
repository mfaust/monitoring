
# REST API

Wir haben versucht, möglichst alles über eine einfach API aufrufbar zu bekommen.


## Description

Our Monitoring provides an simplyfied API to create and destroy Nodes for Monitoring.
This API helps also to create Annotations and give back Informations about all known Hosts

## Examples

## helps

```
    curl \
      http://localhost/api/v2/help
```

## Custom configuration

### add
```
    HOSTNAME=monitoring-16-01.coremedia.vm

    curl \
      --silent \
      --request POST \
      --data '{ "ports": [3306,9100,28017] }' \
      http://localhost/api/v2/config/${HOSTNAME} | \
      json_reformat

    {
       "status": 200,
       "message": "config successful written"
    }
```


### list
```
    HOSTNAME=monitoring-16-01.coremedia.vm

    curl \
      --silent \
      http://localhost/api/v2/config/${HOSTNAME} | \
      json_reformat

    {
      "status" : 200,
      "message" : {
        "ports" : [
           3306,
           9100,
           28017
        ]
      }
    }
```

### remove
```
    curl \
      --silent \
      --request DELETE \
      http://localhost/api/v2/config/${HOSTNAME} | \
      json_reformat

    {
      "status": 200,
      "message": "configuration succesfull removed"
    }
```
---

## Nodes

### add Node to Monitoring

Das hinzufügen wird über einen `POST` Request ermöglicht. Hierbei kann über `--data` json formatierte Parameter mitgegeben werden:

Aktuell funktionieren folgende Paramaeter:

| Parameter   | Typ     | default | Beschreibung |
| :---------   | :-----: | :-----: | :----------- |
| `force`      | bool    | false   | wenn `true` gesetzt ist, werden alle vorher gefundenen Informationen über die Node gelöscht **ACHTUNG** dazu zählt auch eine ggf. vorher durchgefürte _Custom Configuration_ |
| `discovery`  | bool    | true    | schaltet die automatische ServiceDiscovery der CoreMedia Applicationen ab |
| `icinga`     | bool    | false   | deaktiviert den Icinga Support |
| `grafana`    | bool    | false   | deaktiviert den Grafana Support. Dadrurch werden keine Dashboards hinzugefügt |
| `tags`       | Array   | []      | Eine Liste von Tags, die an die Node in Grafana gehängt werden |
| `annotation` | bool    | true    | setzt eine Annotation für das erzeugen einer Node |
| `overview`   | bool    | false   | ermöglicht das Anlegen eines Overview Templates in Grafana |
| `config`     | Hash    | {}      | Ein Hash für das direkte schreiben einer Konfiguration |

**Beispiel eines Parametersatzes**

    {
      "force": true,
      "discovery": false,
      "icinga": false,
      "grafana": false,
      "tags": [
        "development",
        "git-0000000"
      ],
      "annotation": true,
      "overview": true,
      "config": {
        "graphite-identifier": "development-system",
        "ports": [50199,51099],
        "display-name": "foo.bar.com",
        "services": ["cae-live","content-managment-server"]
      }
    }

#### Configuration

Zur Zeit können folgende Parameter bei `config` benutzt werden:

| Parameter             | Beschreibung                                                                                     | Beispiel                                              |
| :---------            | :-----------                                                                                     | :-------                                              |
| `graphite-identifier` | bestimmt den Speicherpfad für die TSDB                                                           | `"graphite-identifier": "development-system"`         |
|                       | wird bei Cloud-Services benötigt                                                                 |                                                       |
| `ports`               | überschreibt die feste default Portliste der CoreMedia Applikationen mit einem eigen Portbereich | `"ports": [50199,51099]`                              |
|                       | dadurch ist es möglich auf ggf. geänderte Portbereiche Rücksicht nehmen zu können                |                                                       |
| `display-name`        | ändert den Anzeigenamen in _Grafana_                                                             | `"display-name": "foo.bar.com"`                       |
| `services`            | **ergänzt** die durch die Service-Discovery gefundenen Services                                  | `"services": ["cae-live","content-managment-server"]` |
|                       | dadurch ist es möglich, eine definierte Liste von Services festzulegen, die existieren müssen    |                                                       |


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

| Parameter   | Typ     | default | Beschreibung |
| :---------   | :-----: | :-----: | :----------- |
| `force`      | bool    | false   | wenn `true` gesetzt ist, werden alle vorher gefundenen Informationen über die Node gelöscht **ACHTUNG** dazu zählt auch eine ggf. vorher durchgefürte _Custom Configuration_ |
| `icinga`     | bool    | true    | deaktiviert den Icinga Support |
| `grafana`    | bool    | true    | deaktiviert den Grafana Support. Hierbei bleiben die Dashboards erhalten! |
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
      --data '{ "grafana": false }' \
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




