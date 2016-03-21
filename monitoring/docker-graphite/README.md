# docker-graphite

## based on
alpine:latest

## includes
 - graphite-web
 - whisper
 - carbon-cache
 - nginx

## Ports
 - 2003: the Carbon line receiver port
 - 7002: the Carbon cache query port
 - 8080: the Graphite-Web port

## memory-footprint
~220MiB

## usage
Small and simple configuration located in ``config.rc``

### requirements
Require an mysql Docker like my own [docker-mysql](https://github.com/bodsch/docker-mysql).

### build
    ./build.sh

### run
    ./run.sh

