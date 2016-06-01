# docker-nexus

Minimal Image with OSS Nexus 2.xx

Based on alpine:edge

## to build

    docker build --rm --tag docker-nexus .

## to run

    docker run -d -p 8081:8081 --name nexus docker-nexus

## to test

    curl http://localhost:8081/service/local/status

## to determine the port that the container is listening on

    docker ps nexus

## to lock at logs

    docker logs -f nexus 

## to login

Default credentials are: `admin` / `admin123`


