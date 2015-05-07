FROM centos:6.6
RUN yum -y -q upgrade
RUN yum -y -q install curl unzip java-1.8.0-openjdk-headles tar sudo

#consult-template
RUN curl -s -L \
  https://github.com/hashicorp/consul-template/releases/download/v0.9.0/consul-template_0.9.0_linux_amd64.tar.gz | \
  tar xz -C /usr/bin --strip-components=1

#tomcat
ADD files/tomcat-installation-7.1.7-12.zip /tmp/tomcat-installation.zip
RUN unzip /tmp/tomcat-installation.zip -d /tomcat && \
  rm -f /tmp/tomcat-installation.zip  && /tomcat/install.sh && rm -fr /tomcat


# supervisord
RUN curl -s -L https://bootstrap.pypa.io/ez_setup.py | python
RUN easy_install supervisor
ADD files/supervisord.conf /etc/supervisord.conf

#set catalina properties
ENV CATALINA_PID /var/run/coremedia/cm7-preview-tomcat.pid
ENV CATALINA_HOME /opt/coremedia/cm7-tomcat-installation
ENV CATALINA_OUT /var/log/coremedia/cm7-preview-tomcat.out
ENV CATALINA_TMPDIR /var/tmp/coremedia/cm7-preview-tomcat
ENV CATALINA_BASE /opt/coremedia/cm7-preview-tomcat

CMD ["/usr/bin/supervisord"]
