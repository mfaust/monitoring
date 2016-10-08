#!/usr/bin/ruby
#
# 07.08.2016 - Bodo Schulz
#
#
# v0.9.0

# -----------------------------------------------------------------------------

require 'yaml'

lib_dir    = File.expand_path( '../../lib', __FILE__ )

require sprintf( '%s/collectd-plugin', lib_dir )

config_file = '/etc/cm-monitoring.yaml'

if( File.exist?( config_file ) )

  config = YAML.load_file( config_file )

  @logDir       = config['logDirectory']   ? config['logDirectory']   : '/tmp/log'
  @cacheDir     = config['cacheDirectory'] ? config['cacheDirectory'] : '/tmp/cache'

  @interval     = config['collectd-plugin']['interval'] ? config['collectd-plugin']['interval'] : 15

  @memcacheHost = ENV['MEMCACHE_HOST']              ? ENV['MEMCACHE_HOST']              : nil
  @memcachePort = ENV['MEMCACHE_PORT']              ? ENV['MEMCACHE_PORT']              : nil

else
  puts "no configuration exists, use default settings"

  @logDir       = '/tmp/log'
  @cacheDir     = '/tmp/cache'
  @interval     = 15

end

options = {
  'log_dir'      => @logDir,
  'cache_dir'    => @cacheDir,
  'memcacheHost' => @memcacheHost,
  'memcachePort' => @memcachePort,
  'interval'     => @interval
}

# -----------------------------------------------------------------------------

c = CollecdPlugin.new( options )

loop do

  c.run()

  sleep( @interval )

end

# EOF
