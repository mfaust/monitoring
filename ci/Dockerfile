FROM centos:7

RUN curl https://it-autodeploy.coremedia.com/packer/linux/phantomjs-1.9.2-linux-x86_64.tar.gz | tar xz
RUN ln -s phantomjs-1.9.2-linux-x86_64/bin/phantomjs /usr/local/bin
RUN phantomjs --version
