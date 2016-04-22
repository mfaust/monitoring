{
  "id": 2,
  "title": "Blueprint",
  "originalTitle": "Blueprint",
  "tags": [],
  "style": "dark",
  "timezone": "browser",
  "editable": true,
  "hideControls": false,
  "sharedCrosshair": false,
  "rows": [
    {
      "collapse": true,
      "editable": true,
      "height": "150px",
      "panels": [
        {
          "aliasColors": {},
          "bars": false,
          "datasource": "graphite",
          "editable": true,
          "error": false,
          "fill": 1,
          "grid": {
            "leftLogBase": 1,
            "leftMax": null,
            "leftMin": null,
            "rightLogBase": 1,
            "rightMax": null,
            "rightMin": null,
            "threshold1": null,
            "threshold1Color": "rgba(216, 200, 27, 0.27)",
            "threshold2": null,
            "threshold2Color": "rgba(234, 112, 112, 0.22)"
          },
          "id": 1,
          "isNew": true,
          "legend": {
            "avg": false,
            "current": false,
            "max": false,
            "min": false,
            "show": false,
            "total": false,
            "values": false
          },
          "lines": true,
          "linewidth": 1,
          "links": [],
          "nullPointMode": "connected",
          "percentage": false,
          "pointradius": 5,
          "points": false,
          "renderer": "flot",
          "seriesOverrides": [],
          "span": 6,
          "stack": false,
          "steppedLine": false,
          "targets": [
            {
              "refId": "C",
              "target": "aliasByMetric(aliasSub(collectd.%HOST%.CAE-heap_memory.*, '(.*)-', ''))",
              "textEditor": false
            }
          ],
          "timeFrom": null,
          "timeShift": null,
          "title": "CAE Heap Mem",
          "tooltip": {
            "shared": true,
            "value_type": "cumulative"
          },
          "type": "graph",
          "x-axis": true,
          "y-axis": true,
          "y_formats": [
            "bytes",
            "short"
          ]
        },
        {
          "title": "MLS Heap Mem",
          "error": false,
          "span": 6,
          "editable": true,
          "type": "graph",
          "isNew": true,
          "id": 7,
          "datasource": "graphite",
          "renderer": "flot",
          "x-axis": true,
          "y-axis": true,
          "y_formats": [
            "bytes",
            "short"
          ],
          "grid": {
            "leftLogBase": 1,
            "leftMax": null,
            "rightMax": null,
            "leftMin": null,
            "rightMin": null,
            "rightLogBase": 1,
            "threshold1": null,
            "threshold2": null,
            "threshold1Color": "rgba(216, 200, 27, 0.27)",
            "threshold2Color": "rgba(234, 112, 112, 0.22)"
          },
          "lines": true,
          "fill": 1,
          "linewidth": 1,
          "points": false,
          "pointradius": 5,
          "bars": false,
          "stack": false,
          "percentage": false,
          "legend": {
            "show": false,
            "values": false,
            "min": false,
            "max": false,
            "current": false,
            "total": false,
            "avg": false
          },
          "nullPointMode": "connected",
          "steppedLine": false,
          "tooltip": {
            "value_type": "cumulative",
            "shared": true
          },
          "timeFrom": null,
          "timeShift": null,
          "targets": [
            {
              "refId": "A",
              "target": "aliasByMetric(aliasSub(collectd.%HOST%.MLS-heap_memory.*, '(.*)-', ''))",
              "textEditor": true,
              "hide": false
            }
          ],
          "aliasColors": {},
          "seriesOverrides": [],
          "links": []
        },
        {
          "aliasColors": {},
          "bars": false,
          "datasource": "graphite",
          "editable": true,
          "error": false,
          "fill": 1,
          "grid": {
            "leftLogBase": 1,
            "leftMax": null,
            "leftMin": null,
            "rightLogBase": 1,
            "rightMax": null,
            "rightMin": null,
            "threshold1": null,
            "threshold1Color": "rgba(216, 200, 27, 0.27)",
            "threshold2": null,
            "threshold2Color": "rgba(234, 112, 112, 0.22)"
          },
          "id": 15,
          "isNew": true,
          "legend": {
            "avg": false,
            "current": false,
            "max": false,
            "min": false,
            "show": false,
            "total": false,
            "values": false
          },
          "lines": true,
          "linewidth": 1,
          "links": [],
          "nullPointMode": "connected",
          "percentage": false,
          "pointradius": 5,
          "points": false,
          "renderer": "flot",
          "seriesOverrides": [],
          "span": 6,
          "stack": false,
          "steppedLine": false,
          "targets": [
            {
              "refId": "C",
              "target": "alias(collectd.%HOST%.CAE-blob_cache.cm7_counter-size, 'max')",
              "textEditor": false
            },
            {
              "refId": "A",
              "target": "alias(collectd.%HOST%.CAE-blob_cache.cm7_counter-level, 'used')",
              "textEditor": false
            }
          ],
          "timeFrom": null,
          "timeShift": null,
          "title": "CAE BlobCache",
          "tooltip": {
            "shared": true,
            "value_type": "cumulative"
          },
          "type": "graph",
          "x-axis": true,
          "y-axis": true,
          "y_formats": [
            "bytes",
            "short"
          ]
        }
      ],
      "title": "Row"
    },
    {
      "title": "New row",
      "height": "150px",
      "editable": true,
      "collapse": false,
      "panels": [
        {
          "title": "Feeder Live Heap Mem",
          "error": false,
          "span": 6,
          "editable": true,
          "type": "graph",
          "isNew": true,
          "id": 2,
          "datasource": "graphite",
          "renderer": "flot",
          "x-axis": true,
          "y-axis": true,
          "y_formats": [
            "bytes",
            "short"
          ],
          "grid": {
            "leftLogBase": 1,
            "leftMax": null,
            "rightMax": null,
            "leftMin": null,
            "rightMin": null,
            "rightLogBase": 1,
            "threshold1": null,
            "threshold2": null,
            "threshold1Color": "rgba(216, 200, 27, 0.27)",
            "threshold2Color": "rgba(234, 112, 112, 0.22)"
          },
          "lines": true,
          "fill": 1,
          "linewidth": 1,
          "points": false,
          "pointradius": 5,
          "bars": false,
          "stack": false,
          "percentage": false,
          "legend": {
            "show": false,
            "values": false,
            "min": false,
            "max": false,
            "current": false,
            "total": false,
            "avg": false
          },
          "nullPointMode": "connected",
          "steppedLine": false,
          "tooltip": {
            "value_type": "cumulative",
            "shared": true
          },
          "timeFrom": null,
          "timeShift": null,
          "targets": [
            {
              "refId": "B",
              "target": "aliasByMetric(aliasSub(collectd.%HOST%.FEEDER_LIVE-heap_memory.*, '(.*)-', ''))",
              "textEditor": false
            }
          ],
          "aliasColors": {},
          "seriesOverrides": [],
          "links": []
        },
        {
          "title": "Live Feeder Elements",
          "error": false,
          "span": 5,
          "editable": true,
          "type": "graph",
          "isNew": true,
          "id": 11,
          "datasource": "graphite",
          "renderer": "flot",
          "x-axis": true,
          "y-axis": true,
          "y_formats": [
            "none",
            "short"
          ],
          "grid": {
            "leftLogBase": 1,
            "leftMax": null,
            "rightMax": null,
            "leftMin": 0,
            "rightMin": null,
            "rightLogBase": 1,
            "threshold1": null,
            "threshold2": null,
            "threshold1Color": "rgba(216, 200, 27, 0.27)",
            "threshold2Color": "rgba(234, 112, 112, 0.22)"
          },
          "lines": true,
          "fill": 1,
          "linewidth": 1,
          "points": false,
          "pointradius": 5,
          "bars": false,
          "stack": false,
          "percentage": false,
          "legend": {
            "show": false,
            "values": false,
            "min": false,
            "max": false,
            "current": false,
            "total": false,
            "avg": false
          },
          "nullPointMode": "connected",
          "steppedLine": false,
          "tooltip": {
            "value_type": "cumulative",
            "shared": true
          },
          "timeFrom": null,
          "timeShift": null,
          "targets": [
            {
              "refId": "A",
              "target": "collectd.%HOST%.FEEDER_LIVE-feeder.cm7_counter-diff",
              "textEditor": false
            }
          ],
          "aliasColors": {},
          "seriesOverrides": [],
          "decimals": 0,
          "links": []
        },
        {
          "title": "",
          "error": false,
          "span": 1,
          "editable": true,
          "type": "singlestat",
          "isNew": true,
          "id": 12,
          "links": [],
          "datasource": "graphite",
          "maxDataPoints": 100,
          "interval": null,
          "targets": [
            {
              "refId": "A",
              "target": "collectd.%HOST%.FEEDER_LIVE-feeder.cm7_counter-diff",
              "textEditor": true
            }
          ],
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
          "nullPointMode": "connected",
          "valueName": "avg",
          "prefixFontSize": "50%",
          "valueFontSize": "80%",
          "postfixFontSize": "50%",
          "thresholds": "0,50,80",
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
          "decimals": 0
        }
      ]
    },
    {
      "title": "New row",
      "height": "150px",
      "editable": true,
      "collapse": false,
      "panels": [
        {
          "title": "Feeder Preview Heap Mem",
          "error": false,
          "span": 6,
          "editable": true,
          "type": "graph",
          "isNew": true,
          "id": 3,
          "datasource": "graphite",
          "renderer": "flot",
          "x-axis": true,
          "y-axis": true,
          "y_formats": [
            "bytes",
            "short"
          ],
          "grid": {
            "leftLogBase": 1,
            "leftMax": null,
            "rightMax": null,
            "leftMin": null,
            "rightMin": null,
            "rightLogBase": 1,
            "threshold1": null,
            "threshold2": null,
            "threshold1Color": "rgba(216, 200, 27, 0.27)",
            "threshold2Color": "rgba(234, 112, 112, 0.22)"
          },
          "lines": true,
          "fill": 1,
          "linewidth": 1,
          "points": false,
          "pointradius": 5,
          "bars": false,
          "stack": false,
          "percentage": false,
          "legend": {
            "show": false,
            "values": false,
            "min": false,
            "max": false,
            "current": false,
            "total": false,
            "avg": false
          },
          "nullPointMode": "connected",
          "steppedLine": false,
          "tooltip": {
            "value_type": "cumulative",
            "shared": true
          },
          "timeFrom": null,
          "timeShift": null,
          "targets": [
            {
              "refId": "B",
              "target": "aliasByMetric(aliasSub(collectd.%HOST%.FEEDER_PREV-heap_memory.*, '(.*)-', ''))",
              "textEditor": false
            }
          ],
          "aliasColors": {},
          "seriesOverrides": [],
          "links": []
        },
        {
          "title": "Preview Feeder Elements",
          "error": false,
          "span": 5,
          "editable": true,
          "type": "graph",
          "isNew": true,
          "id": 13,
          "datasource": "graphite",
          "renderer": "flot",
          "x-axis": true,
          "y-axis": true,
          "y_formats": [
            "none",
            "short"
          ],
          "grid": {
            "leftLogBase": 1,
            "leftMax": null,
            "rightMax": null,
            "leftMin": 0,
            "rightMin": null,
            "rightLogBase": 1,
            "threshold1": null,
            "threshold2": null,
            "threshold1Color": "rgba(216, 200, 27, 0.27)",
            "threshold2Color": "rgba(234, 112, 112, 0.22)"
          },
          "lines": true,
          "fill": 1,
          "linewidth": 1,
          "points": false,
          "pointradius": 5,
          "bars": false,
          "stack": false,
          "percentage": false,
          "legend": {
            "show": false,
            "values": false,
            "min": false,
            "max": false,
            "current": false,
            "total": false,
            "avg": false
          },
          "nullPointMode": "connected",
          "steppedLine": false,
          "tooltip": {
            "value_type": "cumulative",
            "shared": true
          },
          "timeFrom": null,
          "timeShift": null,
          "targets": [
            {
              "refId": "A",
              "target": "collectd.%HOST%.FEEDER_PREV-feeder.cm7_counter-diff",
              "textEditor": false
            }
          ],
          "aliasColors": {},
          "seriesOverrides": [],
          "decimals": 0,
          "links": []
        },
        {
          "title": "",
          "error": false,
          "span": 1,
          "editable": true,
          "type": "singlestat",
          "isNew": true,
          "id": 14,
          "links": [],
          "datasource": "graphite",
          "maxDataPoints": 100,
          "interval": null,
          "targets": [
            {
              "refId": "A",
              "target": "collectd.%HOST%.FEEDER_LIVE-feeder.cm7_counter-diff",
              "textEditor": true
            }
          ],
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
          "nullPointMode": "connected",
          "valueName": "avg",
          "prefixFontSize": "50%",
          "valueFontSize": "80%",
          "postfixFontSize": "50%",
          "thresholds": "0,50,80",
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
          "decimals": 0
        }
      ]
    },
    {
      "title": "New row",
      "height": "150px",
      "editable": true,
      "collapse": false,
      "panels": [
        {
          "title": "STUDIO Heap Mem",
          "error": false,
          "span": 6,
          "editable": true,
          "type": "graph",
          "isNew": true,
          "id": 6,
          "datasource": "graphite",
          "renderer": "flot",
          "x-axis": true,
          "y-axis": true,
          "y_formats": [
            "bytes",
            "short"
          ],
          "grid": {
            "leftLogBase": 1,
            "leftMax": null,
            "rightMax": null,
            "leftMin": null,
            "rightMin": null,
            "rightLogBase": 1,
            "threshold1": null,
            "threshold2": null,
            "threshold1Color": "rgba(216, 200, 27, 0.27)",
            "threshold2Color": "rgba(234, 112, 112, 0.22)"
          },
          "lines": true,
          "fill": 1,
          "linewidth": 1,
          "points": false,
          "pointradius": 5,
          "bars": false,
          "stack": false,
          "percentage": false,
          "legend": {
            "show": false,
            "values": false,
            "min": false,
            "max": false,
            "current": false,
            "total": false,
            "avg": false
          },
          "nullPointMode": "connected",
          "steppedLine": false,
          "tooltip": {
            "value_type": "cumulative",
            "shared": true
          },
          "timeFrom": null,
          "timeShift": null,
          "targets": [
            {
              "refId": "A",
              "target": "aliasByMetric(aliasSub(collectd.%HOST%.STUDIO-heap_memory.*, '(.*)-', ''))",
              "textEditor": false,
              "hide": false
            }
          ],
          "aliasColors": {},
          "seriesOverrides": [],
          "links": []
        },
        {
          "title": "CMS Heap Mem",
          "error": false,
          "span": 6,
          "editable": true,
          "type": "graph",
          "isNew": true,
          "id": 8,
          "datasource": "graphite",
          "renderer": "flot",
          "x-axis": true,
          "y-axis": true,
          "y_formats": [
            "bytes",
            "short"
          ],
          "grid": {
            "leftLogBase": 1,
            "leftMax": null,
            "rightMax": null,
            "leftMin": null,
            "rightMin": null,
            "rightLogBase": 1,
            "threshold1": null,
            "threshold2": null,
            "threshold1Color": "rgba(216, 200, 27, 0.27)",
            "threshold2Color": "rgba(234, 112, 112, 0.22)"
          },
          "lines": true,
          "fill": 1,
          "linewidth": 1,
          "points": false,
          "pointradius": 5,
          "bars": false,
          "stack": false,
          "percentage": false,
          "legend": {
            "show": false,
            "values": false,
            "min": false,
            "max": false,
            "current": false,
            "total": false,
            "avg": false
          },
          "nullPointMode": "connected",
          "steppedLine": false,
          "tooltip": {
            "value_type": "cumulative",
            "shared": true
          },
          "timeFrom": null,
          "timeShift": null,
          "targets": [
            {
              "refId": "A",
              "target": "aliasByMetric(aliasSub(collectd.%HOST%.CMS-heap_memory.*, '(.*)-', ''))",
              "textEditor": true,
              "hide": false
            }
          ],
          "aliasColors": {},
          "seriesOverrides": [],
          "links": []
        }
      ]
    },
    {
      "title": "New row",
      "height": "150px",
      "editable": true,
      "collapse": true,
      "panels": [
        {
          "title": "CMS Query Pool",
          "error": false,
          "span": 6,
          "editable": true,
          "type": "graph",
          "isNew": true,
          "id": 4,
          "datasource": "graphite",
          "renderer": "flot",
          "x-axis": true,
          "y-axis": true,
          "y_formats": [
            "none",
            "short"
          ],
          "grid": {
            "leftLogBase": 1,
            "leftMax": null,
            "rightMax": null,
            "leftMin": null,
            "rightMin": null,
            "rightLogBase": 1,
            "threshold1": null,
            "threshold2": null,
            "threshold1Color": "rgba(216, 200, 27, 0.27)",
            "threshold2Color": "rgba(234, 112, 112, 0.22)"
          },
          "lines": true,
          "fill": 1,
          "linewidth": 1,
          "points": false,
          "pointradius": 5,
          "bars": false,
          "stack": false,
          "percentage": false,
          "legend": {
            "show": false,
            "values": false,
            "min": false,
            "max": false,
            "current": false,
            "total": false,
            "avg": false
          },
          "nullPointMode": "connected",
          "steppedLine": false,
          "tooltip": {
            "value_type": "cumulative",
            "shared": true
          },
          "timeFrom": null,
          "timeShift": null,
          "targets": [
            {
              "refId": "A",
              "target": "aliasByMetric(aliasSub(collectd.%HOST%.CMS-query_pool.*, '(.*)-', ''))",
              "textEditor": false
            }
          ],
          "aliasColors": {},
          "seriesOverrides": [],
          "links": [],
          "decimals": 0
        },
        {
          "title": "MLS Query Pool",
          "error": false,
          "span": 6,
          "editable": true,
          "type": "graph",
          "isNew": true,
          "id": 5,
          "datasource": "graphite",
          "renderer": "flot",
          "x-axis": true,
          "y-axis": true,
          "y_formats": [
            "none",
            "short"
          ],
          "grid": {
            "leftLogBase": 1,
            "leftMax": null,
            "rightMax": null,
            "leftMin": null,
            "rightMin": null,
            "rightLogBase": 1,
            "threshold1": null,
            "threshold2": null,
            "threshold1Color": "rgba(216, 200, 27, 0.27)",
            "threshold2Color": "rgba(234, 112, 112, 0.22)"
          },
          "lines": true,
          "fill": 1,
          "linewidth": 1,
          "points": false,
          "pointradius": 5,
          "bars": false,
          "stack": false,
          "percentage": false,
          "legend": {
            "show": false,
            "values": false,
            "min": false,
            "max": false,
            "current": false,
            "total": false,
            "avg": false
          },
          "nullPointMode": "connected",
          "steppedLine": false,
          "tooltip": {
            "value_type": "cumulative",
            "shared": true
          },
          "timeFrom": null,
          "timeShift": null,
          "targets": [
            {
              "refId": "A",
              "target": "aliasByMetric(aliasSub(collectd.%HOST%.MLS-query_pool.*, '(.*)-', ''))",
              "textEditor": false
            }
          ],
          "aliasColors": {},
          "seriesOverrides": [],
          "links": [],
          "decimals": 0
        }
      ]
    },
    {
      "title": "New row",
      "height": "150px",
      "editable": true,
      "collapse": false,
      "panels": [
        {
          "title": "CMS stats creations",
          "error": false,
          "span": 6,
          "editable": true,
          "type": "graph",
          "isNew": true,
          "id": 9,
          "datasource": "graphite",
          "renderer": "flot",
          "x-axis": true,
          "y-axis": true,
          "y_formats": [
            "none",
            "short"
          ],
          "grid": {
            "leftLogBase": 1,
            "leftMax": null,
            "rightMax": null,
            "leftMin": null,
            "rightMin": null,
            "rightLogBase": 1,
            "threshold1": null,
            "threshold2": null,
            "threshold1Color": "rgba(216, 200, 27, 0.27)",
            "threshold2Color": "rgba(234, 112, 112, 0.22)"
          },
          "lines": true,
          "fill": 1,
          "linewidth": 1,
          "points": false,
          "pointradius": 5,
          "bars": false,
          "stack": false,
          "percentage": false,
          "legend": {
            "show": false,
            "values": false,
            "min": false,
            "max": false,
            "current": false,
            "total": false,
            "avg": false
          },
          "nullPointMode": "connected",
          "steppedLine": false,
          "tooltip": {
            "value_type": "cumulative",
            "shared": true
          },
          "timeFrom": null,
          "timeShift": null,
          "targets": [
            {
              "refId": "A",
              "target": "alias(collectd.%HOST%.CMS-stats_repository_document_creation.cm7_counter-sum, 'document')",
              "textEditor": false
            },
            {
              "refId": "B",
              "target": "alias(collectd.%HOST%.CMS-stats_repository_folder_creation.cm7_counter-sum, 'folder')",
              "textEditor": false
            },
            {
              "refId": "C",
              "target": "alias(collectd.%HOST%.CMS-stats_repository_version_creation.cm7_counter-sum, 'version')",
              "textEditor": false
            }
          ],
          "aliasColors": {},
          "seriesOverrides": [],
          "links": []
        },
        {
          "title": "CMS Feeder",
          "error": false,
          "span": 6,
          "editable": true,
          "type": "graph",
          "isNew": true,
          "id": 10,
          "datasource": "graphite",
          "renderer": "flot",
          "x-axis": true,
          "y-axis": true,
          "y_formats": [
            "none",
            "short"
          ],
          "grid": {
            "leftLogBase": 1,
            "leftMax": null,
            "rightMax": null,
            "leftMin": null,
            "rightMin": null,
            "rightLogBase": 1,
            "threshold1": null,
            "threshold2": null,
            "threshold1Color": "rgba(216, 200, 27, 0.27)",
            "threshold2Color": "rgba(234, 112, 112, 0.22)"
          },
          "lines": true,
          "fill": 1,
          "linewidth": 1,
          "points": false,
          "pointradius": 5,
          "bars": false,
          "stack": false,
          "percentage": false,
          "legend": {
            "show": false,
            "values": false,
            "min": false,
            "max": false,
            "current": false,
            "total": false,
            "avg": false
          },
          "nullPointMode": "connected",
          "steppedLine": false,
          "tooltip": {
            "value_type": "cumulative",
            "shared": true
          },
          "timeFrom": null,
          "timeShift": null,
          "targets": [
            {
              "refId": "A",
              "target": "aliasByMetric(aliasSub(collectd.%HOST%.CMS-feeder.*, '.*-', ''))",
              "textEditor": false
            }
          ],
          "aliasColors": {},
          "seriesOverrides": [],
          "links": []
        }
      ]
    }
  ],
  "time": {
    "from": "now-1h",
    "to": "now"
  },
  "timepicker": {
    "now": true,
    "refresh_intervals": [
      "5s",
      "10s",
      "30s",
      "1m",
      "5m",
      "15m",
      "30m",
      "1h",
      "2h",
      "1d"
    ],
    "time_options": [
      "5m",
      "15m",
      "1h",
      "6h",
      "12h",
      "24h",
      "2d",
      "7d",
      "30d"
    ]
  },
  "templating": {
    "list": []
  },
  "annotations": {
    "list": []
  },
  "refresh": "30s",
  "schemaVersion": 8,
  "version": 27,
  "links": []
}