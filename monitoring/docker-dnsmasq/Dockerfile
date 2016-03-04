FROM alpine:3.3

MAINTAINER Bodo Schulz <bodo@boone-schulz.de>

LABEL version="0.9.2"

EXPOSE 53

# ---------------------------------------------------------------------------------------

WORKDIR /app
VOLUME  /app

RUN \
  apk --quiet update && \
  apk --quiet upgrade

RUN \
  apk --quiet add \
    supervisor \
    dnsmasq \
    inotify-tools

RUN \
  rm -rf /var/cache/apk/*

ADD rootfs/ /

CMD [ "/usr/bin/supervisord" ]
# CMD [ '/bin/sh' ]
# ENTRYPOINT [ '/opt/startup.sh' ]
