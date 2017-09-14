
FROM bodsch/docker-jolokia:1709-37.1

MAINTAINER Bodo Schulz <bodo.schulz@coremedia.com>

ENV \
  VERSION="1709-37" \
  BUILD_DATE="2017-09-14" \
  TERM=xterm \
  APK_ADD="nano git g++ make go " \
  APK_DEL="nano git g++ make go" \
  GOPATH=/build \
  GOROOT=/usr/lib/go

EXPOSE 8080 8088

# ---------------------------------------------------------------------------------------

COPY build/ /build
COPY rootfs/ /

RUN \
  apk --no-cache update && \
  apk --no-cache upgrade && \
  apk --no-cache add ${APK_ADD}

RUN \
  cd ${GOPATH}/src && \
  go get github.com/gorilla/mux && \
  go build -ldflags="-s -w" -o service-discovery && \
  mv service-discovery /usr/bin


RUN \
  apk --purge del ${APK_DEL} && \
  rm -rfv \
    /tmp/* \
    /var/cache/apk/* \
    ${GOPATH} \
    /usr/lib/go \
    /usr/bin/go* \
    /root/.n* \
    /root/.cache \
    /root/.config \
    /usr/local/*
