      {
        "collapse": false,
        "editable": true,
        "height": "100px",
        "panels": [
          {
            "content": "<h3><center><bold><a href=\"/grafana/dashboard/db/%SHORTHOST%-contentserver-cms\">CMS</a></bold></center></h3>",
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
                "target": "carbon-writer.$host.CMS.Runtime.uptime",
                "refId": "A",
                "textEditor": false
              }
            ],
            "links": [],
            "datasource": "graphite",
            "maxDataPoints": 100,
            "interval": null,
            "cacheTimeout": null,
            "format": "ms",
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
            "id": 2,
            "title": "used Heap Memory",
            "type": "singlestat",
            "span": 1,
            "colorBackground": true,
            "colors": [ "rgba(50, 172, 45, 0.97)", "rgba(237, 129, 40, 0.89)", "rgba(245, 54, 54, 0.9)" ],
            "datasource": "graphite",
            "format": "none",
            "postfix": " %",
            "postfixFontSize": "80%",
            "targets": [
              {
                "refId": "A",
                "target": "carbon-writer.$host.CMS.Memory.heap_memory.used_percent"
              }
            ],
            "thresholds": "85,95",
            "valueFontSize": "100%",
            "valueName": "current"
          },
          {
            "title": "Runlevel",
            "error": false,
            "span": 1,
            "editable": true,
            "type": "singlestat",
            "isNew": true,
            "id": 85,
            "targets": [
              {
                "target": "carbon-writer.$host.CMS.Server.runlevel",
                "refId": "A"
              }
            ],
            "links": [],
            "datasource": null,
            "maxDataPoints": 100,
            "interval": null,
            "cacheTimeout": null,
            "format": "none",
            "prefix": "",
            "postfix": "",
            "nullText": null,
            "valueMaps": [
              {
                "value": "0",
                "op": "=",
                "text": "Offline"
              },
              {
                "value": "1",
                "op": "=",
                "text": "Online"
              },
              {
                "value": "10",
                "op": "=",
                "text": "Maintenance"
              },
              {
                "value": "11",
                "op": "=",
                "text": "Administration"
              }
            ],
            "mappingTypes": [
              {
                "name": "value to text",
                "value": 1
              },
              {
                "name": "range to text",
                "value": 2
              }
            ],
            "mappingType": 1,
            "nullPointMode": "connected",
            "valueName": "current",
            "valueFontSize": "50%",
            "thresholds": "1,2",
            "colorBackground": true,
            "colorValue": false,
            "colors": [
              "rgba(245, 54, 54, 0.9)",
              "rgba(50, 172, 45, 0.97)",
              "rgba(237, 129, 40, 0.89)"
            ]
          },
          {
            "title": "License [days]",
            "error": false,
            "span": 1,
            "editable": true,
            "type": "singlestat",
            "isNew": true,
            "id": 63,
            "targets": [
              {
                "target": "carbon-writer.$host.CMS.Server.license.until.hard.days",
                "refId": "A"
              }
            ],
            "thresholds": "20,10",
            "links": [],
            "datasource": "graphite",
            "format": "none",
            "mappingType": 1,
            "nullPointMode": "connected",
            "valueName": "current",
            "valueFontSize": "100%",
            "colorBackground": true,
            "colorValue": false,
            "colors": [
              "rgba(245, 54, 54, 0.9)",
              "rgba(237, 129, 40, 0.89)",
              "rgba(50, 172, 45, 0.97)"
            ]
          }
        ],
        "title": "CMS"
      }
