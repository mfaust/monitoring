      {
        "collapse": false,
        "editable": true,
        "height": "100px",
        "panels": [
          {
            "content": "<h3><center><bold><a href=\"/grafana/dashboard/db/%SHORTHOST%-contentserver-rls\">RLS</a></bold></center></h3>",
            "editable": true,
            "error": false,
            "id": 10,
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
                "target": "carbon-writer.$host.RLS.Runtime.uptime",
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
            "cacheTimeout": null,
            "colorBackground": true,
            "colorValue": false,
            "colors": [
              "rgba(50, 172, 45, 0.97)",
              "rgba(237, 129, 40, 0.89)",
              "rgba(245, 54, 54, 0.9)"
            ],
            "datasource": "graphite",
            "editable": true,
            "error": false,
            "format": "none",
            "gauge": {
              "maxValue": 100,
              "minValue": 0,
              "show": false,
              "thresholdLabels": false,
              "thresholdMarkers": true
            },
            "id": 11,
            "interval": null,
            "isNew": true,
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
                "target": "carbon-writer.$host.RLS.Memory.heap_memory.used_percent"
              }
            ],
            "thresholds": "85,95",
            "title": "used Heap Memory",
            "type": "singlestat",
            "valueFontSize": "100%",
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
            "title": "Runlevel",
            "error": false,
            "span": 1,
            "editable": true,
            "type": "singlestat",
            "isNew": true,
            "id": 85,
            "targets": [
              {
                "target": "carbon-writer.$host.RLS.Server.runlevel",
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
                "target": "carbon-writer.$host.RLS.Server.license.until.hard.days",
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
          },
          {
            "title": "Sequence Number",
            "error": false,
            "span": 1,
            "editable": true,
            "type": "singlestat",
            "isNew": true,
            "id": 14,
            "targets": [
              {
                "target": "carbon-writer.$host.RLS.Replicator.completedSequenceNumber",
                "refId": "A",
                "hide": false
              }
            ],
            "links": [],
            "datasource": "graphite",
            "maxDataPoints": 100,
            "interval": null,
            "cacheTimeout": null,
            "format": "none",
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
            "title": "diff Sequence Numbers",
            "error": false,
            "span": 1,
            "editable": true,
            "type": "singlestat",
            "isNew": true,
            "id": 15,
            "targets": [
              {
                "hide": false,
                "refId": "A",
                "target": "carbon-writer.$host.RLS.SequenceNumber.diffToMLS"
              },
              {
                "target": "carbon-writer.$host.MLS.Server.Repository.SequenceNumber",
                "refId": "B",
                "hide": true
              },
              {
                "target": "carbon-writer.$host.RLS.Replicator.completedSequenceNumber",
                "refId": "C",
                "hide": true
              },
              {
                "target": "diffSeries(#B, #C)",
                "refId": "D",
                "hide": true
              }
            ],
            "links": [],
            "datasource": "graphite",
            "maxDataPoints": 100,
            "interval": null,
            "cacheTimeout": null,
            "format": "none",
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
            "thresholds": "100,300",
            "colorBackground": true,
            "colorValue": false,
            "colors": [
              "rgba(50, 172, 45, 0.97)",
              "rgba(237, 129, 40, 0.89)",
              "rgba(245, 54, 54, 0.9)"
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
          }
        ],
        "title": "RLS"
      }
