mkdir -p $GOPATH/src/github.com/mitchellh
mv /workspace/packer-source $GOPATH/src/github.com/mitchellh/packer
cd $GOPATH/src/github.com/mitchellh/packer

go get -u github.com/mitchellh/gox

make updatedeps
make dev
cd bin
version=`./packer --version`_`git rev-parse --short=10 HEAD`
zip /workspace/${version}_linux_amd64.zip *
