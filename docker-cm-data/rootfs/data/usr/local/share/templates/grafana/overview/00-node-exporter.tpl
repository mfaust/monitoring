      {
        "collapse": false,
        "editable": true,
        "height": "100px",
        "panels": [
          {
            "content": "<h3>Operating System</h3>",
            "id": 100,
            "links": [],
            "mode": "html",
            "span": 1,
            "title": "",
            "type": "text"
          },
          {
            "title": "Uptime",
            "error": false,
            "span": 1,
            "editable": true,
            "type": "singlestat",
            "isNew": true,
            "id": 70,
            "targets": [
              {
                "target": "carbon-writer.$host.NODE_EXPORTER.uptime.uptime",
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
            "cacheTimeout": null,
            "colorBackground": true,
            "colorValue": false,
            "colors": [
              "rgba(50, 172, 45, 0.97)",
              "rgba(237, 129, 40, 0.89)",
              "rgba(245, 54, 54, 0.9)"
            ],
            "datasource": "graphite",
            "format": "none",
            "gauge": {
              "maxValue": 100,
              "minValue": 0,
              "show": false,
              "thresholdLabels": false,
              "thresholdMarkers": true
            },
            "id": 102,
            "interval": null,
            "links": [],
            "mappingType": 1,
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
            "maxDataPoints": 100,
            "nullPointMode": "connected",
            "nullText": null,
            "postfix": " %",
            "postfixFontSize": "80%",
            "prefix": "",
            "prefixFontSize": "50%",
            "rangeMaps": [
              {
                "from": "null",
                "text": "N/A",
                "to": "null"
              }
            ],
            "span": 1,
            "sparkline": {
              "fillColor": "rgba(31, 118, 189, 0.18)",
              "full": false,
              "lineColor": "rgb(31, 120, 193)",
              "show": false
            },
            "targets": [
              {
                "refId": "A",
                "target": "carbon-writer.$host.NODE_EXPORTER.memory.used_percent"
              }
            ],
            "thresholds": "80,90",
            "title": "used RAM",
            "type": "singlestat",
            "valueFontSize": "80%",
            "valueMaps": [
              {
                "op": "=",
                "text": "N/A",
                "value": "null"
              }
            ],
            "valueName": "current"
          },
          {
            "cacheTimeout": null,
            "colorBackground": true,
            "colorValue": false,
            "colors": [
              "rgba(50, 172, 45, 0.97)",
              "rgba(237, 129, 40, 0.89)",
              "rgba(245, 54, 54, 0.9)"
            ],
            "datasource": "graphite",
            "format": "none",
            "gauge": {
              "maxValue": 100,
              "minValue": 0,
              "show": false,
              "thresholdLabels": false,
              "thresholdMarkers": true
            },
            "id": 103,
            "interval": null,
            "links": [],
            "mappingType": 1,
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
            "maxDataPoints": 100,
            "nullPointMode": "connected",
            "nullText": null,
            "postfix": " %",
            "postfixFontSize": "80%",
            "prefix": "",
            "prefixFontSize": "50%",
            "rangeMaps": [
              {
                "from": "null",
                "text": "N/A",
                "to": "null"
              }
            ],
            "span": 1,
            "sparkline": {
              "fillColor": "rgba(31, 118, 189, 0.18)",
              "full": false,
              "lineColor": "rgb(31, 120, 193)",
              "show": false
            },
            "targets": [
              {
                "refId": "A",
                "target": "carbon-writer.$host.NODE_EXPORTER.swap.used_percent"
              }
            ],
            "thresholds": "80,90",
            "title": "used SWAP",
            "type": "singlestat",
            "valueFontSize": "80%",
            "valueMaps": [
              {
                "op": "=",
                "text": "N/A",
                "value": "null"
              }
            ],
            "valueName": "current"
          },
          {
            "cacheTimeout": null,
            "colorBackground": true,
            "colorValue": false,
            "colors": [
              "rgba(50, 172, 45, 0.97)",
              "rgba(237, 129, 40, 0.89)",
              "rgba(245, 54, 54, 0.9)"
            ],
            "datasource": "graphite",
            "format": "none",
            "gauge": {
              "maxValue": 100,
              "minValue": 0,
              "show": false,
              "thresholdLabels": false,
              "thresholdMarkers": true
            },
            "id": 104,
            "interval": null,
            "links": [],
            "mappingType": 1,
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
            "maxDataPoints": 100,
            "nullPointMode": "connected",
            "nullText": null,
            "postfix": " %",
            "postfixFontSize": "80%",
            "prefix": "",
            "prefixFontSize": "50%",
            "rangeMaps": [
              {
                "from": "null",
                "text": "N/A",
                "to": "null"
              }
            ],
            "span": 1,
            "sparkline": {
              "fillColor": "rgba(31, 118, 189, 0.18)",
              "full": false,
              "lineColor": "rgb(31, 120, 193)",
              "show": false
            },
            "targets": [
              {
                "refId": "A",
                "target": "carbon-writer.$host.NODE_EXPORTER.filesystem.*.used_percent"
              }
            ],
            "thresholds": "80,90",
            "title": "used Filesystem",
            "type": "singlestat",
            "valueFontSize": "80%",
            "valueMaps": [
              {
                "op": "=",
                "text": "N/A",
                "value": "null"
              }
            ],
            "valueName": "current"
          }
        ],
        "title": "Operating System"
      }
