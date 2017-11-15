
FROM busybox:latest

MAINTAINER Bodo Schulz <bodo.schulz@coremedia.com>

ENV \
  VERSION="1711" \
  BUILD_DATE="2017-11-15"

# ---------------------------------------------------------------------------------------

WORKDIR /share

VOLUME [ "/share" ]

COPY rootfs /

ENTRYPOINT "/init/run.sh"

CMD ["tail", "-f", "/dev/null"]
