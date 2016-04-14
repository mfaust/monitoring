
FROM alpine:edge

MAINTAINER Bodo Schulz <bodo@boone-schulz.de>

LABEL version="1.2.2"

EXPOSE 3030

ENV DASHBOARD=coremedia
ENV JQ_VERSION=2.2.2
ENV JQUI_VERSION=1.11.4


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
    curl \
    git \
    nodejs \
    ruby-dev \
    ruby-irb \
    ruby-io-console \
    ruby-rdoc \
    libffi-dev \
    supervisor

RUN \
  gem install --quiet bundle && \
  gem install dashing -v 1.3.4

RUN \
  mkdir /opt && \
  cd /opt && \
  git clone --quiet https://github.com/Shopify/dashing.git && \
  cd dashing && \
  dashing new ${DASHBOARD} && \
  cd ${DASHBOARD} && \
  echo -e "\n" >> Gemfile && \
  echo "gem 'rest-client'"     >> Gemfile && \
  echo "gem 'dotenv'"          >> Gemfile && \
  echo "gem 'pingdom-faraday'" >> Gemfile && \
  echo "gem 'aws-sdk'"         >> Gemfile && \
  echo "gem 'chef'"            >> Gemfile && \
  echo "gem 'chef-config'"     >> Gemfile && \
  echo "gem 'chef-api'"        >> Gemfile && \
  bundle update

RUN \
  ln -s /usr/lib/ruby/gems/2.2.0/gems/dashing-* /usr/lib/ruby/gems/2.2.0/gems/dashing

RUN \
  curl --silent https://code.jquery.com/jquery-${JQ_VERSION}.min.js > /usr/lib/ruby/gems/2.2.0/gems/dashing/javascripts/jquery.js && \
  curl --silent http://jqueryui.com/resources/download/jquery-ui-${JQUI_VERSION}.zip > /tmp/jquery-ui-${JQUI_VERSION}.zip && \
  cd /tmp && \
  unzip jquery-ui-${JQUI_VERSION}.zip && \
  cp /tmp/jquery-ui-${JQUI_VERSION}/*.min.js     /usr/lib/ruby/gems/2.2.0/gems/dashing/javascripts/ && \
  cp /tmp/jquery-ui-${JQUI_VERSION}/*.min.css    /usr/lib/ruby/gems/2.2.0/gems/dashing/templates/project/assets/stylesheets/ && \
  cp /tmp/jquery-ui-${JQUI_VERSION}/images/*     /usr/lib/ruby/gems/2.2.0/gems/dashing/templates/project/assets/images/

RUN \
  rm -rf /tmp/jquery* && \
  rm -rf /opt/dashing/${DASHBOARD}/jobs/buzzwords.rb && \
  rm -rf /opt/dashing/${DASHBOARD}/jobs/convergence.rb && \
  rm -rf /opt/dashing/${DASHBOARD}/jobs/sample.rb && \
  rm -rf /opt/dashing/${DASHBOARD}/jobs/twitter.rb && \
  rm -rf /opt/dashing/${DASHBOARD}/jobs/timeline.rb

RUN \
  apk del --purge \
    git \
    build-base \
    ruby-dev \
    libffi-dev && \
  rm -rf /var/cache/apk/*

ADD rootfs/ /

WORKDIR /opt/dashing/${DASHBOARD}

CMD [ "/opt/startup.sh" ]

# EOF
