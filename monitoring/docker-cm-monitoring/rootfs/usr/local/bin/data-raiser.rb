#!/usr/bin/ruby
#
# 12.08.2016 - Bodo Schulz
#
#
# v1.0.0

# -----------------------------------------------------------------------------

require 'yaml'

lib_dir    = File.expand_path( '../../lib', __FILE__ )

application_config = '/etc/cm-application.json'
service_config     = '/etc/cm-service.json'

require sprintf( '%s/jolokia-data-raiser', lib_dir )

config_file = '/etc/cm-monitoring.yaml'

if( File.exist?( config_file ) )

  config = YAML.load_file( config_file )

  @logDir           = config['monitoring']['log_dir']              ? config['monitoring']['log_dir']              : '/tmp/log'
  @cacheDir         = config['monitoring']['cache_dir']            ? config['monitoring']['cache_dir']            : '/tmp/cache'
  @jolokia_host     = config['monitoring']['jolokia']['host']      ? config['monitoring']['jolokia']['host']      : 'localhost'
  @jolokia_port     = config['monitoring']['jolokia']['port']      ? config['monitoring']['jolokia']['port']      : 8080

else
  puts "no configuration exists, use default settings"

  @logDir       = '/tmp/log'
  @cacheDir     = '/tmp/cache'
  @jolokia_host = 'localhost'
  @jolokia_port = 8080

end

options = {
  'log_dir'      => @logDir,
  'cache_dir'    => @cacheDir,
  'jolokia_host' => @jolokia_host,
  'jolokia_port' => @jolokia_port
}

# -----------------------------------------------------------------------------

r = JolokiaDataRaiser.new( options, application_config, service_config )

# -----------------------------------------------------------------------------

# NEVER FORK THE PROCESS!
# the used supervisord will control all
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

# -----------------------------------------------------------------------------

