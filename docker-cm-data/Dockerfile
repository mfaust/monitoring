
FROM busybox:latest

MAINTAINER Bodo Schulz <bodo.schulz@coremedia.com>

LABEL version="1704-02.1"

# ---------------------------------------------------------------------------------------

WORKDIR /share

VOLUME [ "/share" ]

ADD rootfs/data /share

CMD ["tail", "-f", "/dev/null"]
