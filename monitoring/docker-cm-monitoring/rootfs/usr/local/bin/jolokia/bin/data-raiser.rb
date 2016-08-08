#!/usr/bin/ruby
#
# 31.07.2016 - Bodo Schulz
#
#
# v0.5.4

# -----------------------------------------------------------------------------

config_dir = File.expand_path( '../../config', __FILE__ )
lib_dir    = File.expand_path( '../../lib', __FILE__ )

application_config = sprintf( '%s/cm-application.json', config_dir )
service_config     = sprintf( '%s/cm-service.json'    , config_dir )

require sprintf( '%s/jolokia-data-raiser', lib_dir )

# -----------------------------------------------------------------------------

r = JolokiaDataRaiser.new( application_config, service_config )

# -----------------------------------------------------------------------------

# now, fork a process and call the run() function every 15 seconds
pid = fork do
  stop = false

  Signal.trap('INT')  { stop = true }
  Signal.trap('HUP')  { stop = true }
  Signal.trap('TERM') { stop = true }
  Signal.trap('QUIT') { stop = true }

  until stop
    # do your thing
    r.run()
    sleep(15)
  end
end

# -----------------------------------------------------------------------------

