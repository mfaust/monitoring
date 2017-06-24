      {
        "collapse": false,
        "editable": true,
        "height": "100px",
        "panels": [
          {
            "content": "<h3><center><bold><a href=\"/grafana/dashboard/db/%SHORTHOST%-http-server-status\">HTTP</a></bold></center></h3>",
            "editable": true,
            "error": false,
            "id": 1,
            "isNew": true,
            "links": [],
            "mode": "html",
            "span": 1,
            "title": "",
            "type": "text"
          },
          {
            "title": "Service Uptime",
            "error": false,
            "span": 1,
            "editable": true,
            "type": "singlestat",
            "isNew": true,
            "id": 70,
            "targets": [
              {
                "target": "carbon-writer.$host.HTTP_STATUS.uptime",
                "refId": "A",
                "textEditor": false
              }
            ],
            "links": [],
            "datasource": "graphite",
            "maxDataPoints": 100,
            "interval": null,
            "cacheTimeout": null,
            "format": "s",
            "nullText": null,
            "mappingType": 1,
            "nullPointMode": "connected",
            "valueName": "current",
            "valueFontSize": "70%",
            "thresholds": "",
            "colorBackground": false,
            "colorValue": false,
            "decimals": 0,
            "valueMaps": [
              {
                "value": "0",
                "op": "=",
                "text": "OFFLINE"
              }
            ]
          },
          {
            "title": "workers busy",
            "error": false,
            "span": 1,
            "editable": true,
            "type": "singlestat",
            "isNew": true,
            "id": 71,
            "targets": [
              {
                "target": "carbon-writer.$host.HTTP_STATUS.workers.busy",
                "refId": "A",
                "textEditor": false
              }
            ],
            "links": [],
            "datasource": "graphite",
            "maxDataPoints": 100,
            "interval": null,
            "cacheTimeout": null,
            "format": "s",
            "nullText": null,
            "mappingType": 1,
            "nullPointMode": "connected",
            "valueName": "current",
            "valueFontSize": "70%",
            "thresholds": "",
            "colorBackground": false,
            "colorValue": false,
            "decimals": 0,
            "valueMaps": [
              {
                "value": "0",
                "op": "=",
                "text": "OFFLINE"
              }
            ]
          },
          {
            "title": "workers idle",
            "error": false,
            "span": 1,
            "editable": true,
            "type": "singlestat",
            "isNew": true,
            "id": 72,
            "targets": [
              {
                "target": "carbon-writer.$host.HTTP_STATUS.workers.idle",
                "refId": "A",
                "textEditor": false
              }
            ],
            "links": [],
            "datasource": "graphite",
            "maxDataPoints": 100,
            "interval": null,
            "cacheTimeout": null,
            "format": "s",
            "nullText": null,
            "mappingType": 1,
            "nullPointMode": "connected",
            "valueName": "current",
            "valueFontSize": "70%",
            "thresholds": "",
            "colorBackground": false,
            "colorValue": false,
            "decimals": 0,
            "valueMaps": [
              {
                "value": "0",
                "op": "=",
                "text": "OFFLINE"
              }
            ]
          }
        ],
        "title": "HTTP"
      }
