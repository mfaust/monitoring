ideen
=====

reduzierung der I/O Belastung

  - zusammenlegender einzelnen bulk_*json dateien
  - Daten in-memory halten


http://graphite.readthedocs.io/en/latest/config-carbon.html#relay-rules-conf
http://obfuscurity.com/2016/09/Benchmarking-Graphite-on-NVMe

icinga2
http://www.claudiokuenzler.com/blog/578/icinga2-advanced-usage-arrays-dictionaries-monitoring-partitions-nrpe#.VxijqOJ9670



API v2

Redesign of my ReST API with more and cleaner capabilities.


POST to create

 /v2/config/:host
    curl -X POST http://localhost/api/v2/config/foo -d '{ "ports": [200,300] }'

 /v2/host/:host
    curl -X POST http://localhost/api/v2/host/foo -d '{ "discovery": false, "icinga2": false, "grafana": false, "services": [ "cae-live-1", "content-managment-server": { "port": 41000 }  ], "tags": [ "development", "git-0000000" ] }'


GET

DELETE

