
FROM bodsch/docker-jolokia:1.3.7

MAINTAINER Bodo Schulz <bodo.schulz@coremedia.com>

ARG HOSTS

ENV \
  VERSION="1711" \
  BUILD_DATE="2017-11-06" \
  TERM=xterm \
  TZ='Europe/Berlin' \
  GOPATH=/build \
  GOROOT=/usr/lib/go \
  HOSTS=${HOSTS:-}

EXPOSE 8080 8088

# ---------------------------------------------------------------------------------------

RUN \
  apk --quiet --no-cache update && \
  apk --quiet --no-cache upgrade

COPY build/ /build

RUN \
  apk add --quiet --no-cache --virtual .build-deps \
    git g++ make go && \
  apk add --quiet --no-cache \
    curl && \
  cd ${GOPATH}/src && \
  go get github.com/gorilla/mux && \
  go build -ldflags="-s -w" -o service-discovery && \
  mv service-discovery /usr/bin && \
  apk del --quiet .build-deps && \
  rm -rf \
    /tmp/* \
    /build \
    /var/cache/apk/* \
    ${GOPATH} \
    /usr/lib/go \
    /usr/bin/go* \
    /root/.n* \
    /root/.cache \
    /root/.config \
    /usr/local/* && \
  [ ! -n "${HOSTS}" ] && echo "${HOSTS}" >> /etc/hosts

COPY rootfs/ /

WORKDIR /

HEALTHCHECK \
  --interval=5s \
  --timeout=2s \
  --retries=12 \
  CMD curl --silent --fail http://localhost:8080/jolokia || exit 1
