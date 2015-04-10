FROM centos:6.6
RUN yum -y -q upgrade
RUN yum -y -q install wget

RUN yum -y -q install http://it-autodeploy.coremedia.com/packer/rhel/6/x86_64/RPMS/chef-11.18.6-1.el6.x86_64.rpm

RUN wget -q --no-cookies --no-check-certificate --header "Cookie: oraclelicense=accept-securebackup-cookie" "http://it-autodeploy.coremedia.com/packer/linux/jdk-7u75-linux-x64.rpm" -O /tmp/jdk-7-linux-x64.rpm
RUN yum -y -q install /tmp/jdk-7-linux-x64.rpm
RUN alternatives --install /usr/bin/java jar /usr/java/latest/bin/java 200000
RUN alternatives --install /usr/bin/javaws javaws /usr/java/latest/bin/javaws 200000
RUN alternatives --install /usr/bin/javac javac /usr/java/latest/bin/javac 200000
ENV JAVA_HOME /usr/java/latest
