#!/usr/bin/ruby
#
# 12.08.2016 - Bodo Schulz
#
#
# v1.0.0

# -----------------------------------------------------------------------------

require 'yaml'

lib_dir    = File.expand_path( '../../lib', __FILE__ )

require sprintf( '%s/data-collector', lib_dir )

applicationConfigFile = '/etc/cm-application.yaml'
serviceConfigFile     = '/etc/cm-service.yaml'
configFile            = '/etc/cm-monitoring.yaml'

if( File.exist?( configFile ) )

  config = YAML.load_file( configFile )

  @logDir           = config['logDirectory']         ? config['logDirectory']     : '/tmp/log'
  @cacheDir         = config['cacheDirectory']       ? config['cacheDirectory']   : '/tmp/cache'
  @jolokiaHost      = config['jolokia']['host']      ? config['jolokia']['host']  : 'localhost'
  @jolokiaPort      = config['jolokia']['port']      ? config['jolokia']['port']  : 8080

  @memcacheHost     = ENV['MEMCACHE_HOST']           ? ENV['MEMCACHE_HOST']       : nil
  @memcachePort     = ENV['MEMCACHE_PORT']           ? ENV['MEMCACHE_PORT']       : nil

  @scanDiscovery    = config['data-collector']['scan-discovery'] ? config['data-collector']['scan-discovery'] : '10m'

else
  puts "no configuration exists, use default settings"

  @logDir        = '/tmp/log'
  @cacheDir      = '/tmp/cache'
  @jolokiaHost   = 'localhost'
  @jolokiaPort   = 8080
  @memcacheHost  = nil
  @memcachePort  = nil
  @scanDiscovery = '10m'

end

options = {
  :logDirectory          => @logDir,
  :cacheDirectory        => @cacheDir,
  :jolokiaHost           => @jolokiaHost,
  :jolokiaPort           => @jolokiaPort,
  :memcacheHost          => @memcacheHost,
  :memcachePort          => @memcachePort,
  :scanDiscovery         => @scanDiscovery,
  :applicationConfigFile => applicationConfigFile,
  :serviceConfigFile     => serviceConfigFile
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

