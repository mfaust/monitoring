
# ReST API

## Description

Our Monitoring provides an simplyfied API to create and destroy Nodes for Monitoring.
This API helps also to create Annotations and give back Informations about all known Hosts

## Examples

## Custom configuration

### add

    HOSTNAME=monitoring-16-01.coremedia.vm

    curl \
      --silent \
      --request POST \
      --data '{ "ports": [3306,9100,28017] }' \
      http://localhost/api/v2/config/${HOSTNAME} | \
      json_reformat

#### result

    {
       "status": 200,
       "message": "config successful written"
    }

### list

    HOSTNAME=monitoring-16-01.coremedia.vm

    curl \
      --silent \
      http://localhost/api/v2/config/${HOSTNAME} | \
      json_reformat

#### result

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


### remove

    curl \
      --silent \
      --request DELETE \
      http://localhost/api/v2/config/${HOSTNAME} | \
      json_reformat

#### result

    {
      "status": 200,
      "message": "configuration succesfull removed"
    }


## Nodes

### add Node to Monitoring

Das hinzufügen wird über einen `POST` Request ermöglicht. Hierbei kann über `--data` json formatierte Parameter mitgegeben werden:

Aktuell funktionieren folgende Paramaeter:

| Paramerter | Typ | default | Beschreibung |
| ------ | ------------- | ----- | ----- |
| `force`      | bool  | false | löscht vorher alle Informationen über die Node. **ACHTUNG** dazu zählt auch eine ggf. vorher durchgefürte _Custom Configuration_ |
| `discovery`  | bool  | true  | schaltet die ServiceDiscovery der CoreMedia Applicationen ab. |
| `icinga`     | bool  | false | deaktiviert den Icinga Support |
| `grafana`    | bool  | false | deaktivier das hinzufügen von Grafana Dashboards |
| `services`   | Array | []    | Liste von Applicationen, die explizit ins Monitoring müssen ( benötigt `discovery = false` |
| `tags`       | Array | []    | Eine Liste von Tags, die im Grafana benutz werden |
| `annotation` | bool  | true  | setzt eine Annotation für das erzeugen einer Node |
| `overview`   | bool  | false | ermöglicht das anlegen eines Overview Templates im Grafana |

Als Beispiel dient folgendes:

    {
      "force": true,
      "discovery": false,
      "icinga": false,
      "grafana": false,
      "services": [
        "cae-live-1": {},
        "content-managment-server": { "port": 41000 }
      ],
      "tags": [
        "development",
        "git-0000000"
      ],
      "annotation": true,
      "overview": true
    }

    HOSTNAME=pandora-16-01.coremedia.vm

    curl \
      --silent \
      --request POST \
      --data '{ "force": true }' \
      http://localhost/api/v2/host/monitoring-16-01 | \
      json_reformat

#### result

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




# remove Node from Monitoring


    curl -X DELETE http://localhost/api/v2/host/cmx-16-01 -d '{ "grafana": false, "icinga": false }'

# give Information about Node

    curl -X GET http://localhost/api/v2/host/monitoring-16-01


# add Annotations for Node


    curl -X POST http://localhost/api/v2/annotation/monitoring-16-01 --data '{ "command": "deployment", "message": "version 7.1.50", "tags": ["7.1.50"] }'
