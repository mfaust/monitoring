# docker-jolokia

Minimal Image with Apache Tomcat8, openjdk8-jre-base and jolokia.

Based on alpine:edge

jolokia needs an functional DNS to resolve all hostnames.

The Standard DNS they Docker uses are 8.8.8.8 and 8.8.4.4. When you use own DNS, you can export the Environment var DOCKER_DNS to add you own.


## Build

 ```
 docker build --tag=docker-jolokia .
 ```
 or

 ```
 ./build.sh
 ```

## run

 ```
 docker run docker-jolokia
 ```
 or

 ```
 ./run.sh
 ```

## Test

 ```
 curl http://localhost:8080/jolokia/ | python -mjson.tool
 ```

## Ports

* 8080

