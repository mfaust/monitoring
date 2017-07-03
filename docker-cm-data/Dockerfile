
FROM busybox:latest

MAINTAINER Bodo Schulz <bodo.schulz@coremedia.com>

LABEL version="1707-27.1"

# ---------------------------------------------------------------------------------------

WORKDIR /share

VOLUME [ "/share" ]

COPY rootfs /

ENTRYPOINT "/init/run.sh"

CMD ["tail", "-f", "/dev/null"]
