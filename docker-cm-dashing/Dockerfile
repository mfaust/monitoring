
FROM bodsch/docker-dashing:1711.1

MAINTAINER Bodo Schulz <bodo.schulz@coremedia.com>

ENV \
  VERSION="1711" \
  BUILD_DATE="2017-11-09" \
  DASHBOARD="coremedia" \
  ICINGA2_GEM_VERSION="1.0"

EXPOSE 3030

# ---------------------------------------------------------------------------------------

COPY build /build

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
  #
  cd /opt/${DASHBOARD} && \
  count=$(ls -1 /build/*.gem 2> /dev/null | tail -n1) && \
  if [ ! -z ${count} ] ; then \
    gem install --no-rdoc --no-ri ${count} ; \
  else \
    echo "gem 'icinga2', '~> ${ICINGA2_GEM_VERSION}'" >> Gemfile ; \
  fi && \
  #
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

HEALTHCHECK \
  --interval=5s \
  --timeout=2s \
  --retries=12 \
  CMD curl --silent --fail http://localhost:3030/dashing/coremedia || exit 1

CMD [ "/init/run.sh" ]
