      {
        "collapse": false,
        "editable": true,
        "height": "100px",
        "panels": [
          {
            "content": "<h3><center><bold>CMS</bold></center></h3>",
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
                "target": "collectd.%HOST%.CMS-Runtime-uptime.uptime",
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
                "target": "collectd.%HOST%.CMS-Memory-heap_memory.count-used_percent"
              }
            ],
            "thresholds": "85,95",
            "valueFontSize": "100%",
            "valueName": "current"
          },
          {
            "title": "GC Duration",
            "error": false,
            "span": 1,
            "editable": true,
            "type": "singlestat",
            "isNew": true,
            "id": 4,
            "targets": [
              {
                "target": "collectd.%HOST%.CMS-GCParNew-gc_duration.count-duration",
                "refId": "A"
              }
            ],
            "links": [],
            "datasource": "graphite",
            "maxDataPoints": 100,
            "interval": null,
            "cacheTimeout": null,
            "format": "ms",
            "prefix": "",
            "postfix": "",
            "nullText": null,
            "valueMaps": [
              {
                "value": "null",
                "op": "=",
                "text": "N/A"
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
            "rangeMaps": [
              {
                "from": "null",
                "to": "null",
                "text": "N/A"
              }
            ],
            "mappingType": 1,
            "nullPointMode": "connected",
            "valueName": "current",
            "prefixFontSize": "50%",
            "valueFontSize": "80%",
            "postfixFontSize": "50%",
            "thresholds": "",
            "colorBackground": false,
            "colorValue": false,
            "colors": [
              "rgba(245, 54, 54, 0.9)",
              "rgba(237, 129, 40, 0.89)",
              "rgba(50, 172, 45, 0.97)"
            ],
            "sparkline": {
              "show": false,
              "full": false,
              "lineColor": "rgb(31, 120, 193)",
              "fillColor": "rgba(31, 118, 189, 0.18)"
            },
            "gauge": {
              "show": false,
              "minValue": 0,
              "maxValue": 100,
              "thresholdMarkers": true,
              "thresholdLabels": false
            }
          },
          {
            "title": "",
            "error": false,
            "span": 1,
            "editable": true,
            "type": "singlestat",
            "isNew": true,
            "id": 85,
            "targets": [
              {
                "target": "collectd.%HOST%.CMS-Server-server.count-runlevel",
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
            "thresholds": "",
            "colorBackground": false,
            "colorValue": false
          }
        ],
        "title": "CMS"
      }
