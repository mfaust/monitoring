
FROM bodsch/docker-icinga2:1707-28.1

MAINTAINER Bodo Schulz <bodo.schulz@coremedia.com>

ENV \
  ALPINE_MIRROR="mirror1.hs-esslingen.de/pub/Mirrors" \
  ALPINE_VERSION="v3.6" \
  TERM=xterm \
  APK_ADD="build-base bind-tools drill py2-pip ruby ruby-dev nano" \
  APK_DEL="build-base ruby-dev" \
  GEMS="aws-sdk bigdecimal io-console ipaddress json openssl redis sinatra sinatra-basic-auth thin time_difference"

LABEL version="1707-28.1"

# ---------------------------------------------------------------------------------------

WORKDIR /

RUN \
  echo "http://${ALPINE_MIRROR}/alpine/${ALPINE_VERSION}/main"       > /etc/apk/repositories && \
  echo "http://${ALPINE_MIRROR}/alpine/${ALPINE_VERSION}/community" >> /etc/apk/repositories && \
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

