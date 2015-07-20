FROM ubuntu

ENV GOPATH=/root/gocode
ENV GOROOT=/usr/local/go
ENV PATH=$PATH:/usr/local/go/bin
ENV PATH=$PATH:/root/gocode/bin

RUN apt-get -q update && \
    apt-get -y -q install bzr mercurial wget git tar make zip gcc

RUN wget -q https://storage.googleapis.com/golang/go1.4.2.linux-amd64.tar.gz && \
    tar xzf go*.linux-amd64.tar.gz && \
    rm -rf go*.linux-amd64.tar.gz && \
    mv ./go /usr/local/

RUN go get -u github.com/mitchellh/gox && \
    gox -build-toolchain
