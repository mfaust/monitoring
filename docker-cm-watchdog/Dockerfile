FROM alpine:3.8

MAINTAINER Bodo Schulz <bodo.schulz@coremedia.com>

ENV \
  VERSION="1808" \
  BUILD_DATE="2018-08-31" \
  TERM=xterm \
  TZ='Europe/Berlin'


RUN \
  apk add --update

RUN \
  apk add --no-cache \
    curl \
    bash \
    jq \
    fcgi \
    monitoring-plugins \
    bind-tools \
    redis \
    perl \
    perl-io-socket-ssl \
    perl-io-socket-inet6 \
    perl-socket \
    perl-socket6 \
    perl-mime-lite \
    perl-term-readkey \
    tini \
    tzdata && \
  curl https://raw.githubusercontent.com/mludvig/smtp-cli/v3.9/smtp-cli -o /smtp-cli && \
  chmod +x smtp-cli
#
#COPY rootfs/ /
#
#ENTRYPOINT ["/sbin/tini", "-g", "--"]
#
#
#CMD /watchdog.sh 2> /dev/null

CMD "/bin/bash"
