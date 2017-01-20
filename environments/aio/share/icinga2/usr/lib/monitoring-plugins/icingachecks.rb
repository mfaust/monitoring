#!/usr/bin/ruby

require 'optparse'
require 'json'
require 'logger'
require 'time_difference'

require_relative '/usr/local/lib/logging'
require_relative '/usr/local/lib/mbean'

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

    memcacheHost     = ENV['MEMCACHE_HOST'] ? ENV['MEMCACHE_HOST'] : nil
    memcachePort     = ENV['MEMCACHE_PORT'] ? ENV['MEMCACHE_PORT'] : nil

#     @logDirectory  = settings[:logDirectory]       ? settings[:logDirectory]       : '/tmp'
#    @configFile  = '/etc/cm-monitoring.yaml'

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
          usePercent = service['usePercent'] ? service['usePercent'] : nil
          warning    = service['warning'] ? service['warning']       : nil
          critical   = service['critical'] ? service['critical']     : nil
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


#   def logger()
#
#     logFile      = sprintf( '/tmp/icinga2check.log',  )
#     file         = File.open( logFile, File::WRONLY | File::APPEND | File::CREAT )
#     file.sync    = true
#     log          = Logger.new( file, 'weekly', 1024000 )
#
# #    log = Logger.new( STDOUT )
#     log.level = Logger::DEBUG
#     log.datetime_format = "%Y-%m-%d %H:%M:%S::%3N"
#     log.formatter = proc do |severity, datetime, progname, msg|
#       "[#{datetime.strftime(logger.datetime_format)}] #{severity.ljust(5)} : #{msg}\n"
#     end
#
#     return log
#
#   end


#   def memcache()
#
#     memcacheHost     = ENV['MEMCACHE_HOST'] ? ENV['MEMCACHE_HOST'] : nil
#     memcachePort     = ENV['MEMCACHE_PORT'] ? ENV['MEMCACHE_PORT'] : nil
#     supportMemcache  = false
#
#     if( memcacheHost != nil && memcachePort != nil )
#
#       # enable Memcache Support
#
#       require 'dalli'
#
#       memcacheOptions = {
#         :compress   => true,
#         :namespace  => 'monitoring',
#         :expires_in => 0
#       }
#
#       mc = Dalli::Client.new( sprintf( '%s:%s', memcacheHost, memcachePort ), memcacheOptions )
#
#       supportMemcache = true
#
#       MBean.memcache( mc )
#
#       return mc
#     end
#
#     return false
#
#   end


  def shortHostname( hostname )

    return hostname.split( '.' ).first

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
      difference = difference[:seconds].ceil

#       logger.debug( sprintf( ' now       : %s', n.to_datetime.strftime("%d %m %Y %H:%M:%S") ) )
#       logger.debug( sprintf( ' timestamp : %s', t.to_datetime.strftime("%d %m %Y %H:%M:%S") ) )
#       logger.debug( sprintf( ' difference: %d', difference ) )

      if( difference > critical )
#         logger.error( sprintf( '  %d > %d', difference, critical ) )
        result = STATE_CRITICAL
      elsif( difference > warning || difference == warning )
#         logger.warning( sprintf( '  %d >= %d', difference, warning ) )
        result = STATE_WARNING
      else
        result = STATE_OK
      end

    end

    return result, difference

  end


end
