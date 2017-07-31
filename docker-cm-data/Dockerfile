
FROM busybox:latest

MAINTAINER Bodo Schulz <bodo.schulz@coremedia.com>

ENV \
  VERSION="1707-31.1" \
  BUILD_DATE="2017-07-31"

# ---------------------------------------------------------------------------------------

WORKDIR /share

VOLUME [ "/share" ]

COPY rootfs /

ENTRYPOINT "/init/run.sh"

CMD ["tail", "-f", "/dev/null"]
