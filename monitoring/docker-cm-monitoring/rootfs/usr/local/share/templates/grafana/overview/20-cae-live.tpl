      {
        "collapse": false,
        "editable": true,
        "height": "100px",
        "panels": [
          {
            "content": "<h2><center><bold>CAE Live</bold></center></h2>",
            "editable": true,
            "error": false,
            "id": 39,
            "isNew": true,
            "links": [],
            "mode": "html",
            "span": 1,
            "title": "",
            "type": "text"
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
            "id": 40,
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
                "target": "collectd.%HOST%.CAE_LIVE-Memory-heap_memory.count-used_percent"
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
            "id": 41,
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
                "target": "collectd.%HOST%.CAE_LIVE-Memory-perm_memory.count-used_percent"
              }
            ],
            "thresholds": "85,95",
            "title": "used Perm Memory",
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
            "title": "GC Duration",
            "error": false,
            "span": 1,
            "editable": true,
            "type": "singlestat",
            "isNew": true,
            "id": 42,
            "targets": [
              {
                "target": "collectd.%HOST%.CAE_LIVE-GCParNew-gc_duration.count-duration",
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
            "title": "used UAPI Cache",
            "error": false,
            "span": 1,
            "editable": true,
            "type": "singlestat",
            "isNew": true,
            "id": 43,
            "targets": [
              {
                "target": "collectd.%HOST%.CAE_LIVE-CapConnection-heap_cache.count-used_percent",
                "refId": "A"
              }
            ],
            "links": [],
            "datasource": "graphite",
            "maxDataPoints": 100,
            "interval": null,
            "cacheTimeout": null,
            "format": "none",
            "prefix": "",
            "postfix": " %",
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
            "postfixFontSize": "70%",
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
            "title": "used Blob Cache",
            "error": false,
            "span": 1,
            "editable": true,
            "type": "singlestat",
            "isNew": true,
            "id": 44,
            "targets": [
              {
                "target": "collectd.%HOST%.CAE_LIVE-CapConnection-blob_cache.count-used_percent",
                "refId": "A"
              }
            ],
            "links": [],
            "datasource": "graphite",
            "maxDataPoints": 100,
            "interval": null,
            "cacheTimeout": null,
            "format": "none",
            "prefix": "",
            "postfix": " %",
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
            "postfixFontSize": "70%",
            "thresholds": "90,95",
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
        "title": "CAE Live"
      }