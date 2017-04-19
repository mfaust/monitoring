#!/usr/bin/ruby
# suppres "warning: constant ::Fixnum is deprecated"
$VERBOSE = nil

require 'optparse'
require 'json'
require 'yaml'
require 'logger'
require 'time_difference'

require_relative '/usr/local/share/icinga2/logging'
require_relative '/usr/local/share/icinga2/utils/network'
require_relative '/usr/local/share/icinga2/storage'
require_relative '/usr/local/share/icinga2/mbean'
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

    redisHost    = ENV.fetch( 'REDIS_HOST'       , 'localhost' )
    redisPort    = ENV.fetch( 'REDIS_PORT'       , 6379 )

#     memcacheHost = ENV['MEMCACHE_HOST'] ? ENV['MEMCACHE_HOST'] : nil
#     memcachePort = ENV['MEMCACHE_PORT'] ? ENV['MEMCACHE_PORT'] : 11211

    logger.level = Logger::DEBUG
    @redis       = Storage::RedisClient.new( { :redis => { :host => redisHost } } )
    @mbean       = MBean::Client.new( { :redis => @redis } )
  end


  def readConfig( service )

    file = '/etc/cm-icinga2.yaml'

    usePercent = nil
    warning    = nil
    critical   = nil

    if( File.exist?( file ) )

      begin

        config  = YAML.load_file( file )

        service = config.dig(service)

        if( service != nil )
          usePercent = service.dig('usePercent')
          warning    = service.dig('warning')
          critical   = service.dig('critical')
        end
      rescue YAML::ParserError => e

        logger.error( 'wrong result (no yaml)')
        logger.error( e )
      end
    end

    return {
      :usePercent => usePercent,
      :warning    => warning,
      :critical   => critical
    }

  end


  def shortHostname( hostname )

    # look in the memcache
    memcacheKey = Storage::RedisClient.cacheKey( { :host => hostname, :type => 'dns' })

    data      = @redis.get( memcacheKey )

    if( data == nil )

      data = Utils::Network.resolv( hostname )
      @redis.set( memcacheKey, data )
    end

    hostname = data.dig('short')

    return hostname

  end


  def runningOrOutdated( data )

    if( data == false )
      puts 'CRITICAL - Service not running!?'
      exit STATE_CRITICAL
    end

    dataStatus    = data.dig('status')    || 500
    dataTimestamp = data.dig('timestamp')
    dataValue     = data.dig('value')     # ( data != nil && data['value'] ) ? data['value'] : nil

    if( dataValue == nil )
      puts 'CRITICAL - Service not running!?'
      exit STATE_CRITICAL
    end

    beanTimeout,difference = beanTimeout?( dataTimestamp )

    if( beanTimeout == STATE_CRITICAL )
      puts sprintf( 'CRITICAL - last check creation is out of date (%d seconds)', difference )
      exit beanTimeout
    elsif( beanTimeout == STATE_WARNING )
      puts sprintf( 'WARNING - last check creation is out of date (%d seconds)', difference )
      exit beanTimeout
    end

    return dataValue

  end


  # check timeout of last bean creation
  #  warning  at 30000 ms == 30 seconds
  #  critical at 60000 ms == 60 seconds
  def beanTimeout?( timestamp, warning = 30, critical = 60 )

    result = false
    quorum = 5 # add 5 seconds

    if( timestamp == nil || timestamp.to_s == 'null' )
      result = true
    else
      n = Time.now()
      t = Time.at( timestamp )
      t = t.add_seconds( quorum )

      difference = TimeDifference.between( t, n ).in_each_component
      difference = difference[:seconds].round

#       logger.debug( sprintf( ' now       : %s', n.to_datetime.strftime("%d %m %Y %H:%M:%S") ) )
#       logger.debug( sprintf( ' timestamp : %s', t.to_datetime.strftime("%d %m %Y %H:%M:%S") ) )
#       logger.debug( sprintf( ' difference: %d', difference ) )

      if( difference > critical )
         logger.error( sprintf( '  %d > %d', difference, critical ) )
        result = STATE_CRITICAL
      elsif( difference > warning || difference == warning )
         logger.warn( sprintf( '  %d >= %d', difference, warning ) )
        result = STATE_WARNING
      else
        result = STATE_OK
      end

    end

    return result, difference

  end


end
