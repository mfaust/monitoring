#!/bin/bash

HOSTNAME="osmc.local"

wait_for_port() {

  port="${1}"

  RETRY=20

  until [ ${RETRY} -le 0 ]
  do
    echo " [i] waiting for content-server to come up"
    sleep 15s

    nc   ${HOSTNAME} ${port} < /dev/null > /dev/null

    [ $? -eq 0 ] && break

    sleep 10s
    RETRY=$(expr ${RETRY} - 1)
  done
}

wait_for_ior() {

 port="${1}"

  RETRY=20

  until [ ${RETRY} -le 0 ]
  do
    echo " [i] waiting for content-server ior"
    sleep 5s

    curl --fail http://${HOSTNAME}:${port}/coremedia/ior 2> /dev/null

    [ $? -eq 0 ] && break

    sleep 10s
    RETRY=$(expr ${RETRY} - 1)
  done
}


reset_hard() {

  for i in caefeeder-live caefeeder-preview cae-live-1 cae-preview content-feeder content-management-server mongod editor-webapp elastic-worker master-live-server replication-live-server sitemanager solr studio user-changes workflow-server mysql-default
  do
    service $i stop
  done

  find /var/log/coremedia/ -type f -exec rm -f {} \;

  yum -y erase mysql-community-common mysql-community-client mysql-community-libs-compat mysql-community-libs mysql-community-server mysql-community-devel

  rm -rf /var/lib/mysql-default
  rm -f /var/tmp/coremedia/test-data
  rm -rf /var/lib/mongo/*
  rm -rf /var/coremedia/solr-data

  mkdir -p /var/tmp/coremedia/test-data/content/

  [ -f /tmp/cms9-blueprint-workspace-content-blobs.zip ] && cp /tmp/cms9-blueprint-workspace-content-blobs.zip /var/tmp/coremedia/

  cd /var/tmp/coremedia/
  [ -f cms9-blueprint-workspace-content-blobs.zip ] && unzip -o cms9-blueprint-workspace-content-blobs.zip
  mv workspace/modules/extensions/corporate/test-data/content/__blob  /var/tmp/coremedia/test-data/content/
  cp -u workspace/modules/extensions/am/test-data/content/__blob/*    /var/tmp/coremedia/test-data/content/__blob/

  cd /var/tmp/deploy

  [ -f deployment-archive.zip ] && unzip -o deployment-archive.zip

  service mongod start

  /var/tmp/deploy/osmc-deploy.sh

  # activate solr jmx
  sed -i \
    -e '/SOLR_HOST=/s/=.*/="osmc.local"/' \
    -e 's|#SOLR_HOST=|SOLR_HOST=|g' \
    -e 's|ENABLE_REMOTE_JMX_OPTS="false"|ENABLE_REMOTE_JMX_OPTS="true"|g' \
    -e 's|#ENABLE_REMOTE_JMX_OPTS=|ENABLE_REMOTE_JMX_OPTS=|g' \
    /etc/default/solr.in.sh

  service solr restart

  # enable mod_status
  echo "Listen *:8081" >> /etc/httpd/ports.conf
  sed -i 's|ExtendedStatus Off|ExtendedStatus On|g' /etc/httpd/mods-available/status.conf
  sed -i 's|Require local|Require all granted|g' /etc/httpd/sites-available/_overview.conf

  # create vhsost.json
  /opt/chef/embedded/bin/ruby /tmp/apache_vhosts.rb > /opt/coremedia/overview/vhosts.json

  service httpd reload

  wait_for_port 40180
  wait_for_port 40280

  wait_for_ior 40180
  wait_for_ior 40280

  sleep 10s


  /opt/coremedia/content-management-server-tools/bin/cm publishall -a -cq "NOT BELOW PATH '/Home'" -t 1 http://${HOSTNAME}:40180/coremedia/ior admin admin http://${HOSTNAME}:40280/coremedia/ior admin admin
  /opt/coremedia/content-management-server-tools/bin/cm serverimport -r -u admin -p admin --no-validate-xml -t 4 /var/tmp/coremedia/test-data/content
  sleep 4s

  /opt/coremedia/content-management-server-tools/bin/cm runlevel -u admin -p admin
  /opt/coremedia/master-live-server-tools/bin/cm runlevel -u admin -p admin
  /opt/coremedia/replication-live-server-tools/bin/cm runlevel -u admin -p admin
  /opt/coremedia/replication-live-server-tools/bin/cm runlevel -u admin -p admin -r online -g 2
  /opt/coremedia/caefeeder-preview-tools/bin/cm resetcaefeeder reset
  /opt/coremedia/caefeeder-live-tools/bin/cm resetcaefeeder reset

  service caefeeder-live restart
  service caefeeder-preview restart

  /opt/coremedia/content-management-server-tools/bin/cm bulkpublish -a -u admin -p admin
  /opt/coremedia/content-management-server-tools/bin/cm bulkpublish -b -u admin -p admin

  tail -F /var/log/coremedia/*/*log
}

reset_hard
