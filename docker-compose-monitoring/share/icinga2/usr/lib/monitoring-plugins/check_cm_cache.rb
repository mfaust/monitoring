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

    @host = self.shortHostname( @host )

    self.check( cache )

  end


  def shortHostname( hostname )

    return hostname.split( '.' ).first

  end


  def check( type )

    # TODO
    # make it configurable
    warning  = 95
    critical = 98

    # get our bean
    data = MBean.bean( @host, @application, 'CapConnection' )

    dataStatus    = data['status']    ? data['status']    : 500
    dataTimestamp = data['timestamp'] ? data['timestamp'] : nil
    dataValue     = ( data != nil && data['value'] ) ? data['value'] : nil
    dataValue     = dataValue.values.first

    case type
    when 'uapi-cache'
      type          = 'UAPI'
      cacheSize     = dataValue['HeapCacheSize']  ? dataValue['HeapCacheSize']  : nil
      cacheLevel    = dataValue['HeapCacheLevel'] ? dataValue['HeapCacheLevel'] : nil
    when 'blob-cache'
      type          = 'BLOB'
      cacheSize     = dataValue['BlobCacheSize']  ? dataValue['BlobCacheSize']  : nil
      cacheLevel    = dataValue['BlobCacheLevel'] ? dataValue['BlobCacheLevel'] : nil
    else

      puts sprintf( 'UNKNOWN - Cache not available' )
      exit STATE_UNKNOWN
    end

    percent  = ( 100 * cacheLevel.to_i / cacheSize.to_i ).to_i


    if( percent == warning || percent <= warning )
      status   = 'OK'
      exitCode = STATE_OK
    elsif( percent >= warning && percent <= critical )
      status   = 'WARNING'
      exitCode = STATE_WARNING
    else
      status   = 'CRITICAL'
      exitCode = STATE_CRITICAL
    end

    puts sprintf( '%s - %s Cache: %d%% used (Used: %s - Max: %s )', status, type, percent, cacheSize.to_filesize, cacheLevel.to_filesize )
    exit exitCode

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
