#!/bin/sh

set -e

# -------------------------------------------------------------------------------------------------

run() {

  . /init/database/mysql.sh

#   . /init/dns.sh

  /usr/local/bin/rest-service.rb
}

run

# EOF
