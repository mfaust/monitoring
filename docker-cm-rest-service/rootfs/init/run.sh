#!/bin/sh

set -e

# -------------------------------------------------------------------------------------------------

run() {

  . /init/dns.sh
  . /init/database/mysql.sh

  /usr/local/bin/rest-service.rb
}

run

# EOF
