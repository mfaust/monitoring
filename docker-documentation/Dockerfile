
FROM bodsch/docker-markdownd

ENV \
  VERSION="1807" \
  BUILD_DATE="2018-07-30" \
  TZ='Europe/Berlin'

EXPOSE 8080 8088

LABEL \
  version="${VERSION}" \
  maintainer="Bodo Schulz <bodo.schulz@coremedia.com>" \
  org.label-schema.build-date=${BUILD_DATE}

COPY rootfs/ /

WORKDIR /data

