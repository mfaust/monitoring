
FROM alpine:edge

MAINTAINER Bodo Schulz <bodo.schulz@coremedia.com>

LABEL version="0.2.0"

EXPOSE 8081

# ENV APACHE_MIRROR=mirror.synyx.de
# ENV TOMCAT_VERSION=8.5.2
# ENV CATALINA_HOME=/opt/tomcat
# ENV PATH $PATH:$CATALINA_HOME/bin

ENV SONATYPE_WORK=/sonatype-work
ENV NEXUS_VERSION=2.13.0-01

ENV JAVA_HOME /opt/java
ENV JAVA_VERSION_MAJOR 8
ENV JAVA_VERSION_MINOR 92
ENV JAVA_VERSION_BUILD 14

# ---------------------------------------------------------------------------------------------------------------------

RUN \
  apk --quiet update

RUN \
  apk --quiet add \
    curl

RUN \
  addgroup \
    -g 111 \
    -S \
    nexus && \
  adduser \
    -S \
    -u 111 \
    -h ${SONATYPE_WORK} \
    -s /bin/false \
    nexus nexus

RUN \
  mkdir -p /opt/sonatype/nexus

RUN \
  curl \
    --fail \
    --silent \
    --location \
    --retry 3 \    
    --output /tmp/glibc-2.21-r2.apk \
    "https://circle-artifacts.com/gh/andyshinn/alpine-pkg-glibc/6/artifacts/0/home/ubuntu/alpine-pkg-glibc/packages/x86_64/glibc-2.21-r2.apk" && \
  apk add --allow-untrusted /tmp/glibc-2.21-r2.apk

RUN \
  curl \
    --fail \
    --silent \
    --location \
    --retry 3 \
    --header "Cookie: oraclelicense=accept-securebackup-cookie; " \
    "http://download.oracle.com/otn-pub/java/jdk/${JAVA_VERSION_MAJOR}u${JAVA_VERSION_MINOR}-b${JAVA_VERSION_BUILD}/server-jre-${JAVA_VERSION_MAJOR}u${JAVA_VERSION_MINOR}-linux-x64.tar.gz" \
     | gunzip \
     | tar -x -C /opt && \
    ln -s /opt/jdk1.${JAVA_VERSION_MAJOR}.0_${JAVA_VERSION_MINOR} ${JAVA_HOME}


RUN \
  cd /opt/sonatype/nexus && \
  curl \
    --fail \
    --silent \
    --location \
    --retry 3 \
    "https://download.sonatype.com/nexus/oss/nexus-${NEXUS_VERSION}-bundle.tar.gz" \
     | gunzip \
     | tar x -C /tmp nexus-${NEXUS_VERSION} && \
     mv /tmp/nexus-${NEXUS_VERSION}/* /opt/sonatype/nexus/ && \
     rm -rf /tmp/nexus-${NEXUS_VERSION}

RUN \
  apk del --purge \
    curl \
    wget && \
  rm -rf /src/* /tmp/* /var/cache/apk/*

VOLUME ${SONATYPE_WORK}

WORKDIR /opt/sonatype/nexus

# USER nexus
ENV CONTEXT_PATH /
ENV MAX_HEAP 768m
ENV MIN_HEAP 256m
ENV JAVA_OPTS -server -Djava.net.preferIPv4Stack=true
ENV LAUNCHER_CONF ./conf/jetty.xml ./conf/jetty-requestlog.xml
CMD ${JAVA_HOME}/bin/java \
  -Dnexus-work=${SONATYPE_WORK} -Dnexus-webapp-context-path=${CONTEXT_PATH} \
  -Xms${MIN_HEAP} -Xmx${MAX_HEAP} \
  -cp 'conf/:lib/*' \
  ${JAVA_OPTS} \
  org.sonatype.nexus.bootstrap.Launcher ${LAUNCHER_CONF}


