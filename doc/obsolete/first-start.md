
# Das erste Mal

## Installations

Als Basissystem dient ein Linux (Debian/CentOS).

MacOS bzw. Windows sollten ähnlich funktionieren.


### Docker-Engine

Zum Betrieb der Toolbox wird eine `docker-engine` benötigt.

Die Empfehlung hierbei ist eine Version >= `17.04`

Je nach Distribution muß dazu eine bereits bestehende Docker Installation entfernt werden und ggf. das Repositoriy von *docker-ce* eingebunden werden.

**Debian**

```bash
apt-get remove \
  docker \
  docker-engine

apt-get install \
  apt-transport-https \
  ca-certificates \
  curl \
  python-software-properties

curl -fsSL https://download.docker.com/linux/debian/gpg | sudo apt-key add -

add-apt-repository \
  "deb [arch=amd64] https://download.docker.com/linux/debian \
  $(lsb_release -cs) \
  stable"

apt-get update

apt-get install docker-ce
```

**CentOS**

```bash
yum remove \
  docker \
  docker-common \
  container-selinux \
  docker-selinux \
  docker-engine

yum install -y \
  yum-utils

yum-config-manager \
  --add-repo \
  https://download.docker.com/linux/centos/docker-ce.repo

yum makecache \
  fast

yum install \
  docker-ce
```

### Docker-Compose

Neben dem eigentlichen `docker` benötigen wir noch das `docker-compose` binary.
Dieses bietet eine einfach Möglichkeit, viele Container und deren Abhängigkeiten einfach zu orchestrieren.

```bash
COMPOSE_VERSION="1.16.1"
URL="https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)"

curl -L ${URL} > /usr/bin/docker-compose_${COMPOSE_VERSION}

ln -s /usr/bin/docker-compose_${COMPOSE_VERSION} /usr/bin/docker-compose
```

### Post-Installation (optional)

Wenn ein spezieller User `docker` benutzen soll, benötigen wir noch eine entsprechende Gruppe und fügen diesen User dier Gruppe hinzu:

```bash
groupadd docker

usermod -aG docker $USER
```

Damit wäre die Basisvoraussetzung erfüllt.


### Monitoring-Toolbox

Als nächstes muß die CoreMedia Monitoring-Toolbox installiert werden.

```bash
cd ~
mkdir cm-monitoring-toolbox
cd cm-monitoring-toolbox

git clone https://github.com/cm-xlabs/monitoring.git
```

Nach dem erfolgreichen clonen sollte ungefähr diese Verzeichnissstruktur vorhanden sein:

```bash
monitoring
  ├── bin
  ├── docker-cm-carbon-client
  ├── docker-cm-data
  ├── docker-cm-data-collector
  ├── docker-cm-external-discover
  ├── docker-cm-grafana-client
  ├── docker-cm-graphite-client
  ├── docker-cm-icinga-client
  ├── docker-cm-rest-service
  ├── docker-cm-service-discovery
  ├── documentation
  ├── environments
  │    ├── aio
  │    │    ├── docker-compose.yml
  │    │    └── environments.yml
  │    ├── data-capture
  │    └── data-visualization
  │
  ├── incubator
  ├── praese
  └── tools
```

Alle Verzeichnisse, die mit `docker-cm` beginnen, beinhalten die komplette CoreMedia Logik bezüglich des Monitorings, oder sind spezielle Clients für OpenSource Komponenten.
Im Verzeichniss `environments` befinden sich 3 verschieden Monitoringumgebungen:

  * `aio` (All-In-One) - beinhaltet die komplette Toolbox. Dies ist die Basis für diesen Schnelleinstieg.
  * `data-capture` - beinhaltet alle Services um Daten zu erfassen und an externe Services weiterzuleiten. In unserem Fall wäre es
  * `data-visualization` - beinhaltet alle Services um Monitoringdaten darzustellen.

#### Entwicklungsstände

Wir versuchen die Toolbox ständig weiter zu entwickeln und nehmen Wünsche und Anregungen gern auf.
Daher kan es vorkommen, dass der *master* Branch ein einem instabilen Zustand ist.
Um einen stabilen Zweig Entwicklungstand zu ermöglichen werden diese mit einem *Tag* versehen

```bash
$ git tag
1707-30
1708-31
1710
cosmos-1708-31
```
Um einen dieser stabilen Tags nutzen zu können, muß man diesen im git auschecken

```bash
$ git checkout tags/1710
Note: checking out 'tags/1710'.
```
Damit wäre die Installation aller Komponenten abgeschlossen.























Wenn man den Monitoring das erste Mal starten möchte, reicht ein Aufruf von `docker-compose`.

Dazu muß man sich in das Verzeichniss begeben, in dem sich die entsprechende YAML Konfiguration befindet:


    cd environments/aio
    docker-compose up --build

Hierbei werden
 - alle bestehenden Abhängigkeiten aufgelöst
 - die benötigten Container heruntergeladen
 - die Container mit der CoreMedia Logik gebaut
 - alle Container gestartet

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
