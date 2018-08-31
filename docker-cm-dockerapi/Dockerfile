# python:3-alpine
FROM alpine:3.8

MAINTAINER Bodo Schulz <bodo.schulz@coremedia.com>

ENV LANG C.UTF-8

EXPOSE 8080

RUN \
  apk update  --quiet --no-cache  && \
  apk upgrade --quiet --no-cache  && \
  apk add --quiet --no-cache \
    python3 iptables ip6tables tzdata && \
  pip3 install --quiet --upgrade pip

RUN \
  pip3 install --quiet \
    docker \
    flask \
    flask-restful

RUN \
  rm -rf \
    /root/.cache \
    /tmp/* \
    /var/cache/apk/*

COPY rootfs/ /

CMD ["python3", "-u", "/server.py"]

# CMD "/bin/bash"
