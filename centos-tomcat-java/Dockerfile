FROM centos:6.6
RUN yum -y -q upgrade
RUN yum -y -q install curl

RUN yum -y -q install java-1.8.0-openjdk-headless

RUN curl -s http://mirror.cc.columbia.edu/pub/software/apache/tomcat/tomcat-7/v7.0.61/bin/apache-tomcat-7.0.61.zip \
 -o tomcat.zip && \
 unzip tomcat.zip && \
 rm -f tomcat.zip && \
 ln -s apache-tomcat-7.0.61 /tomcat

RUN curl -s -L \
  https://github.com/hashicorp/consul-template/releases/download/v0.9.0/consul-template_0.9.0_linux_amd64.tar.gz | \
  tar xz -C /usr/local && ln -s /usr/local/consul-template_0.9.0_linux_amd64 /consul-template

COPY ./docker-entrypoint.sh /
ENTRYPOINT ["/consul-template/consul-template"]
CMD["--help"]
