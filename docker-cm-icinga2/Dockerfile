
FROM bodsch/docker-icinga2:1711.4

MAINTAINER Bodo Schulz <bodo.schulz@coremedia.com>

ENV \
  VERSION="1711" \
  BUILD_DATE="2017-11-09" \
  TERM=xterm \
  APK_ADD="py2-pip ruby-dev nano" \
  APK_DEL="ruby-dev" \
  GEMS="aws-sdk ipaddress mini_cache redis"

# ---------------------------------------------------------------------------------------

COPY rootfs/ /

RUN \
  apk --no-cache update && \
  apk --no-cache upgrade && \
  apk --no-cache add ${APK_ADD} && \
  gem install --no-rdoc --no-ri ${GEMS} && \
  pip install \
    --trusted-host http://d.pypi.python.org/simple --upgrade pip && \
  apk --purge del ${APK_DEL} && \
  rm -rf \
    /tmp/* \
    /var/cache/apk/*
