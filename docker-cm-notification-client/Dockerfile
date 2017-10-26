
FROM alpine:3.6

MAINTAINER Bodo Schulz <bodo.schulz@coremedia.com>

ENV \
  ALPINE_MIRROR="mirror1.hs-esslingen.de/pub/Mirrors" \
  ALPINE_VERSION="v3.6" \
  TERM=xterm \
  BUILD_DATE="2017-10-26" \
  BUILD_TYPE="stable" \
  BEANSTALKD_VERSION="1.10" \
  APK_ADD="build-base git ruby ruby-dev nano" \
  APK_DEL="build-base git ruby-dev" \
  GEMS="aws-sdk beaneater ipaddress json rufus-scheduler tzinfo-data"

EXPOSE 11300

LABEL \
  version="1710"

# ---------------------------------------------------------------------------------------

RUN \
  echo "http://${ALPINE_MIRROR}/alpine/${ALPINE_VERSION}/main"       > /etc/apk/repositories && \
  echo "http://${ALPINE_MIRROR}/alpine/${ALPINE_VERSION}/community" >> /etc/apk/repositories && \
  apk --no-cache update && \
  apk --no-cache upgrade && \
  apk --no-cache add ${APK_ADD} && \
  [ -d /opt ] || mkdir /opt &&\
  cd /opt && \
  git clone https://github.com/kr/beanstalkd.git && \
  cd beanstalkd && \
  #
  # build stable packages
  if [ "${BUILD_TYPE}" == "stable" ] ; then \
    echo "switch to stable Tag v${BEANSTALKD_VERSION}" && \
    git checkout tags/v${BEANSTALKD_VERSION} 2> /dev/null ; \
  fi && \
  #
  sed -i 's,sys/fcntl.h,fcntl.h,' sd-daemon.c && \
  make && \
  mv beanstalkd /usr/bin/ && \
  mkdir /var/cache/beanstalkd && \
  /usr/bin/beanstalkd -v && \
  #
  gem install --no-rdoc --no-ri ${GEMS}

#  apk del --purge ${APK_ADD} && \
#  rm -rf \
#    /opt/* \
#    /tmp/* \
#    /var/cache/apk/

COPY rootfs/ /

ENTRYPOINT [ "/init/run.sh" ]

CMD ["/bin/sh"]

# EOF

