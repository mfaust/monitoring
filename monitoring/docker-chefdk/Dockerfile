# drone ruby base

FROM       debian:jessie
MAINTAINER Bodo Schulz

RUN apt-get update && apt-get -qqy install curl

#RUN wget --no-cookies --quiet  https://opscode-omnibus-packages.s3.amazonaws.com/debian/6/x86_64/chefdk_0.10.0-1_amd64.deb --output-document=/tmp/chefdk_0.10.0-1_amd64.deb && \
#  dpkg -i /tmp/chefdk_0.10.0-1_amd64.deb && \
#  rm --force /tmp/chefdk_0.10.0-1_amd64.deb && \

RUN curl -L https://www.opscode.com/chef/install.sh > /tmp/install_chefdk.sh && \
  /bin/bash -x -e /tmp/install_chefdk.sh

# RUN locale-gen en_US.UTF-8

