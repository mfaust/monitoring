#!/bin/bash

set -e
set -x

B2D_URL="https://github.com/boot2docker/boot2docker/releases/download/v1.6.0/boot2docker.iso"

apt-get -y -q update
apt-get install -y -q genisoimage wget p7zip-full cpio xz-utils

#--------------------------------------------------------------------
# B2D
#--------------------------------------------------------------------
# Download boot2docker
wget --no-verbose --quiet --no-check-certificate -O b2d.iso ${B2D_URL}

# Mount it up
7z x b2d.iso
rm -f b2d.iso
cp -a boot /tmp
mv /tmp/boot/initrd.img /tmp

# Extract the core filesystem
EXTRACT_DIR="/tmp/extract"
rm -rf ${EXTRACT_DIR}
mkdir -p ${EXTRACT_DIR}
pushd ${EXTRACT_DIR}
xz --format=lzma --decompress --stdout /tmp/initrd.img | cpio -i -H newc -d
popd

#--------------------------------------------------------------------
# Customization
#--------------------------------------------------------------------
# Script to add in public key
cat <<EOF > ${EXTRACT_DIR}/etc/rc.d/packer
mkdir -p /home/docker/.ssh
chmod 0700 /home/docker/.ssh
cat <<KEY >/home/docker/.ssh/authorized_keys
ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEA6NF8iallvQVp22WDkTkyrtvp9eWW6A8YVr+kz4TjGYe7gHzIw+niNltGEFHzD8+v1I2YJ6oXevct1YeS0o9HZyN1Q9qgCgzUFtdOKLv6IedplqoPkcmF0aYet2PkEDo3MlTBckFXPITAMzF8dJSIFo9D8HfdOV0IAdx4O7PtixWKn5y2hMNG0zQPyUecp4pzC6kivAIhyfHilFR61RGL+GPXQ2MWZWFYbAGjyiYJnAmCP3NOTd0jMZEnDkbUvxhMmBYSdETk1rRgm+R4LOzFUGaHqHDLKLX+FIPKcF96hrucXzcWyLbIbEgE98OHlnVYCzRdK8jlqm8tehUc9c9WhQ== vagrant insecure public key
KEY
chmod 0600 /home/docker/.ssh/authorized_keys
chown -R docker:staff /home/docker/.ssh
EOF
chmod +x ${EXTRACT_DIR}/etc/rc.d/packer

# Configure boot to add public key
echo "/etc/rc.d/packer" >> ${EXTRACT_DIR}/opt/bootsync.sh

#--------------------------------------------------------------------
# Package
#--------------------------------------------------------------------
# Make the initrd.img image...
pushd ${EXTRACT_DIR}
find | cpio -o -H newc | xz -9 --format=lzma > /tmp/initrd.img
popd

# Make the ISO
pushd /tmp
mv initrd.img boot
mkdir newiso
mv boot newiso
popd
mkisofs -l -J -R -V b2d-packer -no-emul-boot -boot-load-size 4 \
 -boot-info-table -b boot/isolinux/isolinux.bin \
 -c boot/isolinux/boot.cat -o boot2docker-packer.iso /tmp/newiso
