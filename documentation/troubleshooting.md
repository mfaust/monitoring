Fehleranalyse / -beseitigung
============================


# Logfiles

# DNS

Wir benötigen generell eine funktionierende DNS Auflösung!
Um diese zu gewährleisten kann man auf den integrierten *dnsdock* Docker Container zurückgreifen.
Dieser kann mit mehreren Upstream DNS konfiguriert werden

    cd ~/cm-monitoring-toolbox/envirinment/${ENVIRONMENT}

    vi docker-compose.yaml

         dnsdock:
           .
           .
           command: " --nameserver='10.1.2.63:53' --nameserver='10.1.2.14:53' --http=:80 --alias --ttl=120"

Diese Nameserver können auch dynamisch - zum Beispiel über Environment Variablen - gesetzt werden:

           command: "--nameserver='${DNS_1}:53' --nameserver='${DNS_2}:53' --http=:80" --alias --ttl=120"





