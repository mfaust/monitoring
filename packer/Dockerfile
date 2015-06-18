FROM ubuntu

ENV GOPATH=/root/gocode
ENV GOROOT=/usr/local/go
ENV PATH=$PATH:/usr/local/go/bin
ENV PATH=$PATH:/root/gocode/bin

RUN apt-get -q update && \
    apt-get -y -q install bzr mercurial wget git tar make zip

RUN wget -q https://storage.googleapis.com/golang/go1.4.2.linux-amd64.tar.gz && \
    tar xzf go*.linux-amd64.tar.gz && \
    rm -rf go*.linux-amd64.tar.gz && \
    mv ./go /usr/local/

RUN go get -u github.com/mitchellh/gox && \
    mkdir -p $GOPATH/src/github.com/mitchellh && \
    cd $GOPATH/src/github.com/mitchellh/ && \
    git clone https://github.com/mitchellh/packer.git && \
    cd packer && \
    make updatedeps && \
    make dev && \
    cd bin && \
    version=`./packer --version`_`git rev-parse --short=10 HEAD` && \
    echo $version > /tmp/packer_version && \
    zip /tmp/packer.zip *
