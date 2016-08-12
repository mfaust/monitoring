#!/usr/bin/ruby
#
# 07.08.2016 - Bodo Schulz
#
#
# v0.9.0

# -----------------------------------------------------------------------------

lib_dir    = File.expand_path( '../../lib', __FILE__ )

require sprintf( '%s/collectd-plugin', lib_dir )

config_file = '/etc/cm-monitoring.yaml'

if( File.exist?( config_file ) )

  config = YAML.load_file( config_file )

  @logDir    = config['monitoring']['log_dir']              ? config['monitoring']['log_dir']              : '/tmp/log'
  @cacheDir  = config['monitoring']['cache_dir']            ? config['monitoring']['cache_dir']            : '/tmp/cache'

  @interval  = config['monitoring']['collectd-plugin']['interval'] ? config['monitoring']['collectd-plugin']['interval'] : 15

else
  puts "no configuration exists, use default settings"

  @logDir       = '/tmp/log'
  @cacheDir     = '/tmp/cache'
  @interval     = 15

end

options = {
  'log_dir'      => @logDir,
  'cache_dir'    => @cacheDir,
  'interval'     => @interval
}

# -----------------------------------------------------------------------------

c = CollecdPlugin.new( options )

loop do

  c.run()

  sleep( @interval )

end

# EOF
