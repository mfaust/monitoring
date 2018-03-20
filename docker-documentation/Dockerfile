
FROM bodsch/docker-markdownd

ENV \
  BUILD_DATE="2018-03-20" \
  TZ='Europe/Berlin'

EXPOSE 8080 8088

LABEL \
  version="1803" \
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

COPY rootfs/ /

WORKDIR /data

