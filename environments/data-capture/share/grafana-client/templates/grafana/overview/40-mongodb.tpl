      {
        "collapse": false,
        "editable": true,
        "height": "100px",
        "panels": [
          {
            "content": "<h3><center><bold><a href=\"/grafana/dashboard/db/%HOST%-mongodb\">MongoDB</a></bold></center></h3>",
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
                "target": "collectd.%HOST%.MONGODB-uptime.uptime",
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
                "target": "collectd.%HOST%.MONGODB-heap_memory.count-used_percent"
              }
            ],
            "thresholds": "85,95",
            "valueFontSize": "100%",
            "valueName": "current"
          }
        ],
        "title": "MongoDB"
      }
