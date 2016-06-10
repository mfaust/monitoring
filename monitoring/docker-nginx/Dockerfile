
FROM docker-alpine-base:latest

MAINTAINER Bodo Schulz <bodo.schulz@coremedia.com>

LABEL version="1.0.0"

ENV TERM xterm

EXPOSE 80

# ---------------------------------------------------------------------------------------

RUN \
  apk --quiet update 

RUN \
  apk --quiet add \
    bash \
    nginx

RUN \
  rm -rf /var/cache/apk/*

RUN \
  mkdir /run/nginx

ADD rootfs/ /

## VOLUME  ["/etc/nginx" ]

WORKDIR '/etc/nginx'

# Initialize and run Supervisor
ENTRYPOINT [ "/opt/startup.sh" ]

# ---------------------------------------------------------------------------------------
