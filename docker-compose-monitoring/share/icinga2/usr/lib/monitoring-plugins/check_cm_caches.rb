#!/usr/bin/ruby

require 'optparse'
require 'json'
require 'logger'

require_relative '/usr/local/lib/mbean.rb'


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

class Icinga2Check_CM_Cache

  STATE_OK        = 0
  STATE_WARNING   = 1
  STATE_CRITICAL  = 2
  STATE_UNKNOWN   = 3
  STATE_DEPENDENT = 4

  def initialize( settings = {} )

    @host        = settings[:host]        ? settings[:host]        : nil
    @application = settings[:application] ? settings[:application] : nil
    cache        = settings[:cache]       ? settings[:cache]       : nil

    @cacheDirectory = '/var/cache/monitoring'

#    logFile = sprintf( '%s/monitoring.log', @logDirectory )
#    file      = File.open( logFile, File::WRONLY | File::APPEND | File::CREAT )
#    file.sync = true
#    @log = Logger.new( file, 'weekly', 1024000 )
    @log = Logger.new( STDOUT )
    @log.level = Logger::DEBUG
    @log.datetime_format = "%Y-%m-%d %H:%M:%S::%3N"
    @log.formatter = proc do |severity, datetime, progname, msg|
      "[#{datetime.strftime(@log.datetime_format)}] #{severity.ljust(5)} : #{msg}\n"
    end

    @memcacheHost     = ENV['MEMCACHE_HOST'] ? ENV['MEMCACHE_HOST'] : nil
    @memcachePort     = ENV['MEMCACHE_PORT'] ? ENV['MEMCACHE_PORT'] : nil
    @supportMemcache  = false

    MBean.logger( @log )

    if( @memcacheHost != nil && @memcachePort != nil )

      # enable Memcache Support

      require 'dalli'

      memcacheOptions = {
        :compress   => true,
        :namespace  => 'monitoring',
        :expires_in => 0
      }

      @mc = Dalli::Client.new( sprintf( '%s:%s', @memcacheHost, @memcachePort ), memcacheOptions )

      @supportMemcache = true

      MBean.memcache( @memcacheHost, @memcachePort )
    end

    self.validate( cache )

    case cache
    when 'uapi-cache'
      self.uapiCache()
    when 'blob-cache'
      self.blobCache()
    end

  end

  def shortHostname( hostname )

    shortHostname   = hostname.split( '.' ).first

    return shortHostname

  end


  def validate( cache )

#     # uapi-cache,blob-cache
#     case cache
#     when 'uapi-cache'
#       @feederServer = 'caefeeder-preview'
#     when 'blob-cache'
#       @feederServer = 'content-feeder'
#     else
#       puts sprintf( 'Coremedia Feeder - unknown feeder type %s', @feeder )
#       exit STATE_CRITICAL
#     end

    @host = self.shortHostname( @host )

  end

class Integer
  def to_filesize
    {
      'B'  => 1024,
      'KB' => 1024 * 1024,
      'MB' => 1024 * 1024 * 1024,
      'GB' => 1024 * 1024 * 1024 * 1024,
      'TB' => 1024 * 1024 * 1024 * 1024 * 1024
    }.each_pair { |e, s| return "#{(self.to_f / (s / 1024)).round(2)}#{e}" if self < s }
  end
end


  def uapiCache()

    # TODO
    # make it configurable
    warning  = 85
    critical = 95

    # get our bean
    data = MBean.bean( @host, @application, 'CapConnection' )

    dataStatus    = data['status']    ? data['status']    : 500
    dataTimestamp = data['timestamp'] ? data['timestamp'] : nil
    dataValue     = ( data != nil && data['value'] ) ? data['value'] : nil
    dataValue     = dataValue.values.first

    @log.debug( dataValue )

    heapCacheSize  = dataValue['HeapCacheSize']  ? dataValue['HeapCacheSize']  : nil
    heapCacheLevel = dataValue['HeapCacheLevel'] ? dataValue['HeapCacheLevel'] : nil
    heapCachePercent = ( 100 * heapCacheLevel.to_i / heapCacheSize.to_i ).to_i

    if( heapCachePercent == warning || heapCachePercent <= warning )
      status   = 'OK'
      exitCode = STATE_OK
    elsif( heapCachePercent >= warning && heapCachePercent <= critical )
      status   = 'WARNING'
      exitCode = STATE_WARNING
    else
      status   = 'CRITICAL'
      exitCode = STATE_CRITICAL
    end

    puts sprintf( '%s - UAPI Cache: %d%% used (Used: %s - Max: %s )', status, heapCachePercent, heapCacheLevel.to_filesize, heapCacheSize.to_filesize )
    exit exitCode

  end


  def blobCache()


  end

end


options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: example.rb [options]"

  opts.on('-h', '--host NAME'   , 'Host with running Application')                      { |v| options[:host]  = v }
  opts.on('-a', '--application APP' , 'Name of the running Application')                { |v| options[:application]  = v }
  opts.on('-c', '--cache CACHE' , 'The Cache you want to test [uapi-cache,blob-cache]') { |v| options[:cache] = v }

end.parse!

m = Icinga2Check_CM_Cache.new( options )
