{
  "dashboard": {
    "id": null,
    "title": "%{shorthost} ContentServer",
    "originalTitle": "%{shorthost} ContentServer",
    "tags": "%{tags}",
    "style": "dark",
    "timezone": "browser",
    "editable": true,
    "hideControls": false,
    "sharedCrosshair": false,
    "rows": [
      {
        "collapse": false,
        "editable": true,
        "height": "25px",
        "panels": [
          {
            "content": "<h2><center>CMS</center></h2>",
            "editable": true,
            "error": false,
            "id": 1,
            "isNew": true,
            "links": [],
            "mode": "html",
            "span": 12,
            "title": "",
            "transparent": true,
            "type": "text"
          }
        ],
        "title": "New row"
      },
      {
        "collapse": false,
        "editable": true,
        "height": "150px",

        "panels": [
          {
            "aliasColors": {},
            "bars": false,
            "datasource": null,
            "editable": true,
            "error": false,
            "fill": 3,
            "grid": {
              "threshold1": null,
              "threshold1Color": "rgba(216, 200, 27, 0.27)",
              "threshold2": null,
              "threshold2Color": "rgba(234, 112, 112, 0.22)"
            },
            "id": 2,
            "isNew": true,
            "legend": {
              "alignAsTable": true,
              "avg": false,
              "current": true,
              "max": true,
              "min": true,
              "rightSide": true,
              "show": true,
              "total": false,
              "values": true
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
            "span": 12,
            "stack": false,
            "steppedLine": false,
            "targets": [
              {
                "hide": false,
                "refId": "A",
                "target": "aliasByMetric(aliasSub(collectd.%{host}.CMS-heap_memory.*, '(.*)-', ''))",
                "textEditor": false
              }
            ],
            "timeFrom": null,
            "timeShift": null,
            "title": "CMS Heap Mem",
            "tooltip": {
              "msResolution": false,
              "ordering": "alphabetical",
              "shared": true,
              "value_type": "cumulative"
            },
            "type": "graph",
            "xaxis": {
              "show": true
            },
            "yaxes": [
              {
                "format": "bytes",
                "logBase": 1,
                "max": null,
                "min": null,
                "show": true
              },
              {
                "format": "short",
                "logBase": 1,
                "max": null,
                "min": null,
                "show": true
              }
            ]
          }
        ],
        "title": "Heap Memory"
      }
    ],
    "time": {
      "from": "now-1h",
      "to": "now"
    },
    "timepicker": {
      "now": true,
      "refresh_intervals": [
        "10s",
        "30s",
        "1m",
        "2m",
        "4m",
        "10m"
      ],
      "time_options": [
        "5m",
        "15m",
        "1h",
        "3h",
        "6h",
        "12h",
        "24h",
        "2d",
        "5d",
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
    "schemaVersion": 12,
    "version": 8,
    "links": []
  }
}
