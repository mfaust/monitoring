mkdir -p $GOPATH/src/github.com/mitchellh
source_path=$GOPATH/src/github.com/mitchellh/packer
mv /ws/packer-source $source_path
cd $source_path

git checkout $BRANCH

export XC_ARCH=amd64
export XC_OS="linux darwin windows"

$source_path/scripts/build.sh

version=`$source_path/pkg/linux_amd64/packer --version`_`git rev-parse --short=10 HEAD`

(cd $source_path/pkg/linux_amd64 && zip /ws/packer_${version}_linux_amd64.zip *)
(cd $source_path/pkg/darwin_amd64 && zip /ws/packer_${version}_darwin_amd64.zip *)
(cd $source_path/pkg/windows_amd64 && zip /ws/packer_${version}_windows_amd64.zip *)

