FROM ubuntu:15.04

ADD build-iso.sh /build-iso.sh

RUN chmod +x /build-iso.sh && /build-iso.sh
CMD ["cat", "boot2docker-packer.iso"]
