Tools fürs Monitoring
=====================

monitoring-rest-service
-----------------------

Ein ReST Service, welcher ein Auto Discovery von Tomcat Applikationen durchführt.

Standardmäßig läuft der Service auf Port ```4567```

# start

    ruby bin/monitoring-rest-service.rb

# Add Host

    curl -X POST http://localhost:4567/$hostname
    curl -X POST http://localhost:4567/$hostname/force

# List

    curl http://localhost:4567
    curl http://localhost:4567/$hostname


# löschen

    curl -X DELETE http://localhost:4567/$hostname

