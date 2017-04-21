
FROM busybox:latest

MAINTAINER Bodo Schulz <bodo.schulz@coremedia.com>

LABEL version="1704-03.2"

# ---------------------------------------------------------------------------------------

WORKDIR /share

VOLUME [ "/share" ]

COPY rootfs /

ENTRYPOINT "/init/run.sh"

CMD ["tail", "-f", "/dev/null"]
