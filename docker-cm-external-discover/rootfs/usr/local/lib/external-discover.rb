#!/usr/bin/ruby
#
# 17.12.2016 - Bodo Schulz

# -----------------------------------------------------------------------------

require 'aws-sdk'
require 'json'
require 'rest-client'

require_relative 'logging'
require_relative 'monkey'
require_relative 'aws/client'
require_relative 'cache'
require_relative 'utils/network'

require_relative 'external-discovery/version'
require_relative 'external-discovery/client'
require_relative 'external-discovery/data-consumer'
require_relative 'external-discovery/monitoring-client'

# ---------------------------------------------------------------------------------------
# EOF
