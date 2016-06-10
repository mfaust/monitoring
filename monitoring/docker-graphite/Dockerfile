
FROM docker-alpine-base:latest

MAINTAINER Bodo Schulz <bodo.schulz@coremedia.com>

LABEL version="1.4.0"

# 2003: Carbon line receiver port
# 7002: Carbon cache query port
# 8080: Graphite-Web port
EXPOSE 2003 7002 8080

# ---------------------------------------------------------------------------------------

RUN \
  apk --quiet update

RUN \
  apk --quiet add \
    git \
    nginx \
    python \
    py-pip \
    py-cairo \
    py-twisted \
    py-gunicorn \
    py-mysqldb \
    memcached \
    pwgen \
    mysql-client

RUN \
  pip install --upgrade pip && \
  pip install \
    pytz \
    Django==1.5 \
    python-memcached \
    "django-tagging<0.4" && \
  mkdir /src

RUN \
  git clone https://github.com/graphite-project/whisper.git      /src/whisper      && \
  cd /src/whisper      &&  git checkout 0.9.x &&  python setup.py install

RUN \
  git clone https://github.com/graphite-project/carbon.git       /src/carbon       && \
  cd /src/carbon       &&  git checkout 0.9.x &&  python setup.py install

RUN \
  git clone https://github.com/graphite-project/graphite-web.git /src/graphite-web && \
  cd /src/graphite-web &&  git checkout 0.9.x &&  python setup.py install && \
  mv /opt/graphite/conf/graphite.wsgi.example /opt/graphite/webapp/graphite/graphite_wsgi.py

RUN \
  apk del --purge \
    git && \
  rm -rf /src && \
  rm -rf /tmp/* && \
  rm -rf /var/tmp/* && \
  rm -rf /var/cache/apk/*

ADD rootfs/ /

WORKDIR '/opt/graphite'

VOLUME '/app'

# VOLUME [ '/app/graphite/storage' ]

CMD [ "/opt/startup.sh" ]

# EOF
