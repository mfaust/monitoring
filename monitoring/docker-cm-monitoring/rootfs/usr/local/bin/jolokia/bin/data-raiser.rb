#!/usr/bin/ruby
#
# 31.07.2016 - Bodo Schulz
#
#
# v0.5.4

# -----------------------------------------------------------------------------

require 'yaml'

config_dir = File.expand_path( '../../config', __FILE__ )
lib_dir    = File.expand_path( '../../lib', __FILE__ )

application_config = sprintf( '%s/cm-application.json', config_dir )
service_config     = sprintf( '%s/cm-service.json'    , config_dir )

require sprintf( '%s/jolokia-data-raiser', lib_dir )

options = {
  :log_dir   => '/var/log/monitoring',
  :cache_dir => '/var/cache/monitoring',
  :config    => '/etc/cm-monitoring.yaml'
}

if( File.exist?( options[:config] ) )

  config = YAML.load_file( options[:config] )

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

# -----------------------------------------------------------------------------

r = JolokiaDataRaiser.new( { 'log_dir' => @logDir, 'cache_dir' => @cacheDir, 'jolokia_host' => @jolokia_host, 'jolokia_port' => @jolokia_port }, application_config, service_config )

# -----------------------------------------------------------------------------

# now, fork a process and call the run() function every 15 seconds
# pid = fork do
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
# end

# -----------------------------------------------------------------------------

