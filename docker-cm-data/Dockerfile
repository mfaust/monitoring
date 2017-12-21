
FROM busybox:latest

MAINTAINER Bodo Schulz <bodo.schulz@coremedia.com>

ENV \
  VERSION="1711" \
  http_proxy="http://svc-coremediaweb:Th15Charm1ng-Man@end-bluecoat.next-uk.next.loc:8080/" \
  HTTP_PROXY_AUTH="basic:*:svc-coremediaweb:Th15Charm1ng-Man" \
  BUILD_DATE="2017-11-15"

# ---------------------------------------------------------------------------------------

WORKDIR /share

VOLUME [ "/share" ]

COPY rootfs /

ENTRYPOINT "/init/run.sh"

CMD ["tail", "-f", "/dev/null"]
