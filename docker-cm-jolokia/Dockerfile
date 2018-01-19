
FROM bodsch/docker-jolokia:1.3.7-r3

MAINTAINER Bodo Schulz <bodo.schulz@coremedia.com>

ARG HOSTS

ENV \
  VERSION="1801" \
  BUILD_DATE="2018-01-18" \
  TERM=xterm \
  TZ='Europe/Berlin' \
  GOPATH=/build \
  GOROOT=/usr/lib/go \
  HOSTS=${HOSTS:-}

EXPOSE 8080 8088

# ---------------------------------------------------------------------------------------

COPY build/ /build

RUN \
  apk --quiet --no-cache update && \
  apk add --quiet --no-cache --virtual .build-deps \
    git g++ make go tzdata && \
  apk add --quiet --no-cache \
    curl && \
  cp /usr/share/zoneinfo/${TZ} /etc/localtime && \
  echo ${TZ} > /etc/timezone && \
  cd ${GOPATH}/src && \
  go get github.com/gorilla/mux && \
  go build -ldflags="-s -w" -o service-discovery && \
  mv service-discovery /usr/bin && \
  apk --quiet --purge del .build-deps && \
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
