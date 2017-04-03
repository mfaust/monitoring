#!/usr/bin/ruby
# suppres "warning: constant ::Fixnum is deprecated"
$VERBOSE = nil

require 'optparse'
require 'json'
require 'yaml'
require 'logger'
require 'time_difference'

require_relative '/usr/local/share/icinga2/logging'
require_relative '/usr/local/share/icinga2/storage'
require_relative '/usr/local/share/icinga2/mbean'

# ---------------------------------------------------------------------------------------

class Integer
  def to_filesize
    {
      'B'  => 1024,
      'KB' => 1024 * 1024,
      'MB' => 1024 * 1024 * 1024,
      'GB' => 1024 * 1024 * 1024 * 1024,
      'TB' => 1024 * 1024 * 1024 * 1024 * 1024
    }.each_pair { |e, s| return "#{(self.to_f / (s / 1024)).round(2)} #{e}" if self < s }
  end
end

class Time
  def add_minutes(m)
    self + (60 * m)
  end

  def add_seconds(s)
    self + s
  end
end

class Icinga2Check

  STATE_OK        = 0
  STATE_WARNING   = 1
  STATE_CRITICAL  = 2
  STATE_UNKNOWN   = 3
  STATE_DEPENDENT = 4

  include Logging

  def initialize( settings = {} )

    memcacheHost = ENV['MEMCACHE_HOST'] ? ENV['MEMCACHE_HOST'] : nil
    memcachePort = ENV['MEMCACHE_PORT'] ? ENV['MEMCACHE_PORT'] : 11211

    logger.level = Logger::DEBUG

    @mc          = Storage::Memcached.new( { :host => memcacheHost, :port => memcachePort } )
    @mbean       = MBean::Client.new( { :memcache => @mc } )
  end


  def readConfig( service )

    file = '/etc/cm-icinga2.yaml'

    usePercent = nil
    warning    = nil
    critical   = nil

    if( File.exist?( file ) )

      begin

        config  = YAML.load_file( file )

        service = config[service] ? config[service] : nil

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
    memcacheKey = Storage::Memcached.cacheKey( { :host => hostname, :type => 'dns' })

    data      = @mc.get( memcacheKey )

    if( data == nil )

      data = hostResolve( hostname )
      @mc.set( memcacheKey, data )
    end

    hostname = data.dig(:short)

    return hostname

  end


  def runningOrOutdated( data )

    if( data == false )
      puts 'CRITICAL - Service not running!?'
      exit STATE_CRITICAL
    end

    dataStatus    = data['status']    ? data['status']    : 500
    dataTimestamp = data['timestamp'] ? data['timestamp'] : nil
    dataValue     = ( data != nil && data['value'] ) ? data['value'] : nil

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
