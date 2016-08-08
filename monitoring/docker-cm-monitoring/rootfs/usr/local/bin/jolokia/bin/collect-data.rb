#!/usr/bin/ruby
#
# 07.08.2016 - Bodo Schulz
#
#
# v0.9.0

# -----------------------------------------------------------------------------

# config_dir = File.expand_path( '../../config', __FILE__ )
lib_dir    = File.expand_path( '../../lib', __FILE__ )

# application_config = sprintf( '%s/cm-application.json', config_dir )
# service_config     = sprintf( '%s/cm-service.json'    , config_dir )

require sprintf( '%s/collectd-plugin', lib_dir )

# -----------------------------------------------------------------------------

c = CollecdPlugin.new()

loop do

  c.run()

  sleep( 10 )

end

# EOF
