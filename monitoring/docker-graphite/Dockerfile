FROM bodsch/docker-alpine-base:latest

MAINTAINER Bodo Schulz <bodo.schulz@coremedia.com>

LABEL version="1.4.1"

# 2003: Carbon line receiver port
# 7002: Carbon cache query port
# 8080: Graphite-Web port
EXPOSE 2003 7002 8080

# ---------------------------------------------------------------------------------------

RUN \
  apk --quiet --no-cache update && \
  apk --quiet --no-cache add \
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
    mysql-client && \
  pip install \
    --trusted-host http://d.pypi.python.org/simple --upgrade pip && \
  pip install \
    --trusted-host http://d.pypi.python.org/simple \
    pytz \
    python-memcached==1.57 \
    Django==1.5.12 \
    "django-tagging<0.4" && \
  mkdir /src && \
  git clone https://github.com/graphite-project/whisper.git      /src/whisper      && \
  git clone https://github.com/graphite-project/carbon.git       /src/carbon       && \
  git clone https://github.com/graphite-project/graphite-web.git /src/graphite-web && \
  cd /src/whisper      &&  git checkout 0.9.x &&  python setup.py install --quiet && \
  cd /src/carbon       &&  git checkout 0.9.x &&  python setup.py install --quiet && \
  cd /src/graphite-web &&  git checkout 0.9.x &&  python setup.py install --quiet && \
  mv /opt/graphite/conf/graphite.wsgi.example /opt/graphite/webapp/graphite/graphite_wsgi.py && \
  apk del --purge \
    git && \
    rm -rf /src /tmp/* /var/cache/apk/*

ADD rootfs/ /

WORKDIR '/opt/graphite'

VOLUME '/app'

# VOLUME [ '/app/graphite/storage' ]

CMD [ "/opt/startup.sh" ]

# EOF
