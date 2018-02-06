
FROM alpine:3.7 as builder

COPY build/ /build

WORKDIR /build

RUN \
  apk update --quiet --no-cache && \
  apk upgrade --quiet --no-cache && \
  apk add --quiet --virtual .build-deps \
    g++ git go make && \
  export GOPATH=/build && \
  export GOROOT=/usr/lib/go && \
  cd ${GOPATH}/src && \
  go get github.com/gorilla/mux && \
  go build -ldflags="-s -w" -o service-discovery && \
  mv service-discovery /

# ---------------------------------------------------------------------------------------

FROM bodsch/docker-jolokia:1.4.0-r1

ENV \
  VERSION="1802" \
  BUILD_DATE="2018-02-16" \
  TZ='Europe/Berlin'

EXPOSE 8080 8088

LABEL \
  version="1802" \
  maintainer="Bodo Schulz <bodo.schulz@coremedia.com>" \
  org.label-schema.build-date=${BUILD_DATE}

RUN \
  apk --quiet --no-cache update && \
  apk add --quiet --no-cache --virtual .build-deps \
    tzdata && \
  cp /usr/share/zoneinfo/${TZ} /etc/localtime && \
  echo ${TZ} > /etc/timezone && \
  apk --quiet --purge del .build-deps && \
  rm -rf \
    /tmp/* \
    /var/cache/apk/*

COPY --from=builder /service-discovery /usr/bin/
COPY rootfs/ /

WORKDIR /
