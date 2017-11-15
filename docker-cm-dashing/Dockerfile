
FROM bodsch/docker-dashing:1711.1

MAINTAINER Bodo Schulz <bodo.schulz@coremedia.com>

ENV \
  VERSION="1711" \
  BUILD_DATE="2017-11-15" \
  DASHBOARD="coremedia" \
  ICINGA2_GEM_TYPE="local" \
  ICINGA2_GEM_VERSION="1.0"

EXPOSE 3030

# ---------------------------------------------------------------------------------------

RUN \
  apk --quiet --no-cache update && \
  apk --quiet --no-cache upgrade

COPY build /build

RUN \
  apk add --quiet --no-cache --virtual .build-deps \
    build-base git openssl-dev  ruby-dev && \
  apk add --quiet --no-cache \
    bind-tools drill jq ruby-irb supervisor && \
  gem install --quiet --no-rdoc --no-ri \
    io-console bundler && \
  for g in $(ls -1 /build/*.gem 2> /dev/null) ; do echo $g; gem install --quiet --no-rdoc --no-ri ${g} ; done && \
  cd /opt && \
  smashing new ${DASHBOARD} && \
  rm -f /opt/${DASHBOARD}/jobs/twitter* && \
  rm -f /opt/${DASHBOARD}/dashboards/* && \
  cd ${DASHBOARD} && \
  sed -i "/gem 'twitter'/d" Gemfile && \
  echo "gem 'puma', '~> 3.10'" >> Gemfile && \
  if [ "${ICINGA2_GEM_TYPE}" == "stable" ] ; then \
    echo "gem 'icinga2', '~> ${ICINGA2_GEM_VERSION}'" >> Gemfile ; \
  fi && \
  bundle update --quiet && \
  apk del --quiet .build-deps && \
  rm -rf \
    /tmp/* \
    /build \
    /root/.bundle \
    /root/.gem \
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
