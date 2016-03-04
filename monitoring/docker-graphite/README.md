# docker-graphite

## based on
alpine:3.3

## includes
     graphite-web
     whisper
     carbon-cache

## memory-footprint
~200MiB

## usage

### build
     docker build -t put-your-name-here .

### run
     docker run -P my-graphite-node put-your-name-here

## HINT
use the dynamic DNS Script taken from [blog.amartynov.ru](https://blog.amartynov.ru/archives/dnsmasq-docker-service-discovery) to resolve DNS between Containers