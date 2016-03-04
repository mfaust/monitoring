FROM alpine:3.3

MAINTAINER Bodo Schulz <bodo@boone-schulz.de>

LABEL version="0.9.0"

# 2003: Carbon line receiver port
# 7002: Carbon cache query port
# 8080: Graphite-Web port
EXPOSE 2003 7002 8080

# ---------------------------------------------------------------------------------------

RUN \
  apk add --update \
    git \
    supervisor \
    nginx \
    python \
    py-pip \
    py-cairo \
    py-twisted \
    py-gunicorn && \
  pip install --upgrade pip && \
  pip install \
    pytz \
    Django==1.5 \
    python-memcached \
    "django-tagging<0.4"

RUN \
  mkdir /src && \
  git clone https://github.com/graphite-project/whisper.git      /src/whisper      && \
  git clone https://github.com/graphite-project/carbon.git       /src/carbon       && \
  git clone https://github.com/graphite-project/graphite-web.git /src/graphite-web && \
  cd /src/whisper      &&  git checkout 0.9.x &&  python setup.py install && \
  cd /src/carbon       &&  git checkout 0.9.x &&  python setup.py install && \
  cd /src/graphite-web &&  git checkout 0.9.x &&  python setup.py install && \
  apk del --purge \
    git && \
    rm -rf /src/* /tmp/* /var/cache/apk/*

ADD rootfs/ /

RUN \
  touch /opt/graphite/storage/graphite.db /opt/graphite/storage/index && \
  chown -R nginx /opt/graphite/storage && \
  chmod 0775 /opt/graphite/storage /opt/graphite/storage/whisper && \
  chmod 0664 /opt/graphite/storage/graphite.db && \
  cd /opt/graphite/webapp/graphite && python manage.py syncdb --noinput && \
  mv /opt/graphite/conf/graphite.wsgi.example /opt/graphite/webapp/graphite/graphite_wsgi.py

VOLUME ["/var/log/supervisor"]

CMD [ "/usr/bin/supervisord" ]

# EOF
