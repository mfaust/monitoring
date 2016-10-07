#!/usr/bin/ruby
#
# 12.08.2016 - Bodo Schulz
#
#
# v1.0.0

# -----------------------------------------------------------------------------

require 'yaml'

lib_dir    = File.expand_path( '../../lib', __FILE__ )

applicationConfigFile = '/etc/cm-application.json'
serviceConfigFile     = '/etc/cm-service.json'

require sprintf( '%s/data-collector', lib_dir )

config_file = '/etc/cm-monitoring.yaml'

if( File.exist?( config_file ) )

  config = YAML.load_file( config_file )

  @logDir           = config['monitoring']['log_dir']              ? config['monitoring']['log_dir']          : '/tmp/log'
  @cacheDir         = config['monitoring']['cache_dir']            ? config['monitoring']['cache_dir']        : '/tmp/cache'
  @jolokia_host     = config['monitoring']['jolokia']['host']      ? config['monitoring']['jolokia']['host']  : 'localhost'
  @jolokia_port     = config['monitoring']['jolokia']['port']      ? config['monitoring']['jolokia']['port']  : 8080

  @memcacheHost     = ENV['MEMCACHE_HOST']                         ? ENV['MEMCACHE_HOST']                     : nil
  @memcachePort     = ENV['MEMCACHE_PORT']                         ? ENV['MEMCACHE_PORT']                     : nil

  @scanDiscovery    = config['monitoring']['data-collector']['scan-discovery'] ? config['monitoring']['data-collector']['scan-discovery'] : '10m'

else
  puts "no configuration exists, use default settings"

  @logDir        = '/tmp/log'
  @cacheDir      = '/tmp/cache'
  @jolokia_host  = 'localhost'
  @jolokia_port  = 8080
  @scanDiscovery = '10m'

end

options = {
  'log_dir'               => @logDir,
  'cache_dir'             => @cacheDir,
  'jolokia_host'          => @jolokia_host,
  'jolokia_port'          => @jolokia_port,
  'memcacheHost'          => @memcacheHost,
  'memcachePort'          => @memcachePort,
  'scanDiscovery'         => @scanDiscovery,
  'applicationConfigFile' => applicationConfigFile,
  'serviceConfigFile'     => serviceConfigFile
}

# -----------------------------------------------------------------------------

r = DataCollector.new( options )

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
  sleep( 15 )
end

# -----------------------------------------------------------------------------

