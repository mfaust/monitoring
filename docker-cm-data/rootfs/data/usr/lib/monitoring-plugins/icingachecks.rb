#!/usr/bin/ruby
# suppres "warning: constant ::Fixnum is deprecated"
$VERBOSE = nil

require 'optparse'
require 'json'
require 'yaml'
require 'logger'
require 'mini_cache'

require_relative '/usr/local/share/icinga2/logging'
require_relative '/usr/local/share/icinga2/utils/network'
require_relative '/usr/local/share/icinga2/storage'
require_relative '/usr/local/share/icinga2/mbean'
# require_relative '/usr/local/share/icinga2/cache'
require_relative '/usr/local/share/icinga2/monkey'

# ---------------------------------------------------------------------------------------

class Icinga2Check

  STATE_OK        = 0
  STATE_WARNING   = 1
  STATE_CRITICAL  = 2
  STATE_UNKNOWN   = 3
  STATE_DEPENDENT = 4

  include Logging

  def initialize( settings = {} )

    redis_host    = ENV.fetch( 'REDIS_HOST', 'redis' )
    redis_port    = ENV.fetch( 'REDIS_PORT', 6379 )

    logger.level = Logger::INFO
    @redis       = Storage::RedisClient.new( { redis: { host: redis_host } } )
    @mbean       = MBean::Client.new( { redis: @redis } )
    @cache       = MiniCache::Store.new()
  end


  def read_config( service )

#     logger.debug("read_config( #{service} )")

    use_percent = nil
    warning    = nil
    critical   = nil

    # TODO
    # use internal cache insteed file-access
    cache_key = 'icinga2::config'

    data = @redis.get( cache_key )

#     logger.debug( "cached data: #{data}" )

    if(data.nil?)

      file = '/etc/cm-icinga2.yaml'

      if( File.exist?(file) )

        begin
          config  = YAML.load_file(file)
          @redis.set(cache_key, config, 640) if(config.is_a?(Hash))

        rescue YAML::ParserError => e
          logger.error( 'wrong result (no yaml)')
          logger.error( e )
        end
      end
    end

    unless(data.nil?)
      data    = data.dig(service)

      unless(data.nil?)
        use_percent = data.dig('use_percent') || false
        warning    = data.dig('warning') || 80
        critical   = data.dig('critical') || 90
      end
    end

    {
      use_percent: use_percent,
      warning: warning,
      critical: critical
    }
  end


  def hostname( hostname )
    Utils::Network.resolv( hostname ).dig(:long)
  end


  def running_or_outdated( params = {} )

    host = params.dig(:host)
    data = params.dig(:data)

    unless( data.is_a?(Hash) )
      puts 'CRITICAL - no data found - service not running!?'
      exit STATE_CRITICAL
    end

    status    = data.dig('status')    || 500
    timestamp = data.dig('timestamp')
    value     = data.dig('value')     # ( data != nil && data['value'] ) ? data['value'] : nil

    if( value.nil? )
      output = 'CRITICAL - missing monitoring data - service not running!?'
      logger.info( format( '%s: %s', host, output))
      puts output

      exit STATE_CRITICAL
    end

    state, difference = bean_timeout?( timestamp )

    if( state == STATE_CRITICAL )
      output = format( 'CRITICAL - last check creation is out of date (%d seconds)', difference )
      logger.info( format( '%s: %s', host, output))
      puts output

      exit state
    elsif( state == STATE_WARNING )
      output = format( 'WARNING - last check creation is out of date (%d seconds)', difference )
      logger.info( format( '%s: %s', host, output))
      puts output

      exit state
    end

    value
  end


  # check timeout of last bean creation
  #  warning  at 30000 ms == 30 seconds
  #  critical at 60000 ms == 60 seconds
  def bean_timeout?( timestamp, warning = 30, critical = 60 )

    config   = read_config('timeout')
    warning  = config.dig(:warning)  || warning
    critical = config.dig(:critical) || critical

    result = false
    quorum = 5 # add 5 seconds

    return true if( timestamp == nil || timestamp.to_s == 'null' )

    n = Time.now()
    t = Time.at( timestamp )
    t = t.add_seconds( quorum )

    difference = time_difference( t, n )
    difference = difference[:seconds].round

    if( difference > critical )
      logger.error( format( '  %d > %d', difference, critical ) )
      result = STATE_CRITICAL
    elsif( difference > warning || difference == warning )
      logger.warn( format( '  %d >= %d', difference, warning ) )
      result = STATE_WARNING
    else
      result = STATE_OK
    end

    [result, difference]
  end


  def time_difference( start_time, end_time )

    seconds_diff = (start_time - end_time).to_i.abs

    {
      years: (seconds_diff / 31556952),
      months: (seconds_diff / 2628288),
      weeks: (seconds_diff / 604800),
      days: (seconds_diff / 86400),
      hours: (seconds_diff / 3600),
      minutes: (seconds_diff / 60),
      seconds: seconds_diff,
    }
  end

end
