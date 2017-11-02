
# docker / docker-compose

## `docker`

## `docker-compose`

`docker-compose` unterstützt eine Vielzahl an Parametern

 - herunterladen der binären Container: `docker-compose pull`
 - anzeigen, welche Container gestartet wurden: `docker-compose ps`
 - bauen von Continern, zu denen es keine binäre Version gibt: `docker-compose build`
 - starten der Container: `docker-compose up`
 - hartes beenden der Container: `docker-compose kill`
 - stoppen von Containern und entfernen von erzeugen Netzwerken, Volumes und Images: `docker-compose down`

Einige der Parameter können kombiniert werden:

    docker-compose up --build

Sollen die Container im Hintergrund gestartet werden, muß ein `-d` angehängt werden:

    docker-compose up -d

Mehr Informationen gibt es mit der build-In Hilfe: `docker-compose --help`
