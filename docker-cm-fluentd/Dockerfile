
FROM fluent/fluentd:v1.2.2-onbuild

LABEL \
  version="${VERSION}" \
  maintainer="Bodo Schulz <bodo.schulz@coremedia.com>" \
  org.label-schema.build-date=${BUILD_DATE}

RUN \
  apk update --quiet --no-cache && \
  apk upgrade --quiet --no-cache && \
  apk add --quiet --no-cache --virtual .build-deps \
    build-base ruby-dev

RUN \
  gem install \
    gelf \
    fluent-plugin-secure-forward \
    fluent-plugin-copy_ex \
    fluent-plugin-elasticsearch \
    fluent-plugin-graylog \
    fluent-plugin-concat

RUN \
  gem sources --clear-all && \
  apk del --quiet .build-deps && \
  rm -rf \
    /tmp/* \
    /build  \
    /root/.bundle \
    /root/.gem \
    /var/cache/apk/*

# USER fluentd
