# CoreMedia boot2docker ISO
#
# VERSION               0.0.1

FROM boot2docker/boot2docker

RUN sudo docker pull boot2docker/boot2docker && \
    echo "FROM boot2docker/boot2docker" > Dockerfile && \
    echo "ADD . $ROOTFS/data/" >> Dockerfile && \
    echo "RUN somescript.sh" >> Dockerfile && \
    echo "RUN /make_iso.sh" >> Dockerfile && \
    echo 'CMD ["cat", "boot2docker.iso"]' >> Dockerfile && \
    sudo docker build -t my-boot2docker-img . && \
    sudo docker run --rm my-boot2docker-img > boot2docker.iso
CMD ["cat", "boot2docker.iso"]
