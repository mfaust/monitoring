
FROM bodsch/docker-jolokia:1.3.7

MAINTAINER Bodo Schulz <bodo.schulz@coremedia.com>

ENV \
  VERSION="1711" \
  BUILD_DATE="2017-11-06" \
  TERM=xterm \
  APK_ADD="curl nano git g++ make go " \
  GOPATH=/build \
  GOROOT=/usr/lib/go

EXPOSE 8080 8088

# ---------------------------------------------------------------------------------------

COPY build/ /build

RUN \
  apk --no-cache update && \
  apk --no-cache upgrade && \
  apk --no-cache add ${APK_ADD} && \
  cd ${GOPATH}/src && \
  go get github.com/gorilla/mux && \
  go build -ldflags="-s -w" -o service-discovery && \
  mv service-discovery /usr/bin && \
  apk --purge del ${APK_ADD} && \
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

COPY rootfs/ /

WORKDIR /

HEALTHCHECK \
  --interval=5s \
  --timeout=2s \
  --retries=12 \
  CMD curl --silent --fail http://localhost:8080/jolokia || exit 1
