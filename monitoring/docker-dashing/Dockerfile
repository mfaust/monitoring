
FROM alpine:edge

MAINTAINER Bodo Schulz <bodo@boone-schulz.de>

LABEL version="1.2.0"

EXPOSE 3030

# ---------------------------------------------------------------------------------------

RUN \
  apk --quiet update && \
  apk --quiet upgrade

RUN \
  rm -Rf /var/run && \
  ln -s /run /var/run

RUN \
  apk --quiet add \
    build-base \
    ca-certificates \
    git \
    nodejs \
    ruby-dev \
    ruby-irb \
    ruby-io-console \
    ruby-rdoc \
    supervisor

RUN \
  gem install --quiet bundle && \
  gem install --quiet dashing

RUN \
  mkdir /opt && \
  cd /opt && \
  git clone --quiet https://github.com/Shopify/dashing.git && \
  cd dashing && \
  dashing new icinga2 && \
  cd icinga2 && \
  echo -e "\n" >> Gemfile && \
  echo "gem 'rest-client'"     >> Gemfile && \
  echo "gem 'dotenv'"          >> Gemfile && \
  echo "gem 'pingdom-faraday'" >> Gemfile && \
  echo "gem 'aws-sdk'"         >> Gemfile && \
  bundle update

RUN \
  apk del --purge \
    git \
    build-base \
    ruby-dev && \
  rm -rf /var/cache/apk/*

ADD rootfs/ /

WORKDIR /opt/dashing/icinga2

CMD [ "/opt/startup.sh" ]

# EOF
