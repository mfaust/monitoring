FROM centos:7

RUN yum install -y freetype fontconfig git
RUN curl https://it-autodeploy.coremedia.com/packer/linux/phantomjs-1.9.2-linux-x86_64.tar.gz | tar xz
RUN ln -s /phantomjs-1.9.2-linux-x86_64/bin/phantomjs /usr/local/bin
