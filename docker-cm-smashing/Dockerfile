
FROM bodsch/docker-smashing:1707-27.1

MAINTAINER Bodo Schulz <bodo.schulz@coremedia.com>

ENV \
  VERSION="1707-31.1" \
  BUILD_DATE="2017-07-31" \
  DASHBOARD="coremedia"

EXPOSE 3030

# ---------------------------------------------------------------------------------------

RUN \
  apk --no-cache update && \
  apk --no-cache upgrade && \
  apk --no-cache add \
    build-base \
    git \
    jq \
    openssl-dev \
    ruby-dev \
    openssl-dev \
    supervisor && \
  cd /opt && \
  smashing new ${DASHBOARD} && \
  rm -f /opt/${DASHBOARD}/jobs/twitter* && \
  rm -f /opt/${DASHBOARD}/dashboards/* && \
  cd ${DASHBOARD} && \
  sed -i "/gem 'twitter'/d" Gemfile && \
  echo "gem 'icinga2', '~> 0.7'" >> Gemfile && \
  bundle update && \
  apk del --purge \
    build-base \
    git \
    ruby-dev \
    openssl-dev && \
  rm -rf \
    /tmp/* \
    /build \
    /var/cache/apk/* \
    /usr/lib/ruby/gems/current/cache/*

COPY rootfs/ /

WORKDIR /opt/${DASHBOARD}

CMD [ "/init/run.sh" ]

# ---------------------------------------------------------------------------------------

#
