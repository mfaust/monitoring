#!/usr/bin/ruby

require_relative '/usr/local/lib/icingachecks.rb'

# ---------------------------------------------------------------------------------------

class Icinga2Check_CM_Cache < Icinga2Check

  def initialize( settings = {} )

    @log = logger()
    @mc  = memcache()

    MBean.logger( @log )

    host         = settings[:host]        ? shortHostname( settings[:host] ) : nil
    application  = settings[:application] ? settings[:application] : nil
    cache        = settings[:cache]       ? settings[:cache]       : nil

    self.check( host, application, cache )

  end

  def check( host, application, type )

    config   = readConfig( type )
    warning  = config[:warning]  ? config[:warning]  : 90
    critical = config[:critical] ? config[:critical] : 95

    # get our bean
    data = MBean.bean( host, application, 'CapConnection' )

    if( data == false )
      puts 'CRITICAL - Service not running!?'
      exit STATE_CRITICAL
    else

      dataStatus    = data['status']    ? data['status']    : 500
      dataTimestamp = data['timestamp'] ? data['timestamp'] : nil
      dataValue     = ( data != nil && data['value'] ) ? data['value'] : nil

      if( dataValue == nil )
        puts 'CRITICAL - Service not running!?'
        exit STATE_CRITICAL
      end

      dataValue     = dataValue.values.first

      case type
      when 'uapi-cache'
        type             = 'UAPI'
        cacheMax         = dataValue['HeapCacheSize']  ? dataValue['HeapCacheSize']  : nil # the number of bytes of main memory space that may be used for caching
        cacheCurrentUsed = dataValue['HeapCacheLevel'] ? dataValue['HeapCacheLevel'] : nil # the number of bytes of main memory space that is currently used for caching

      when 'blob-cache'
        type             = 'BLOB'
        cacheMax         = dataValue['BlobCacheSize']  ? dataValue['BlobCacheSize']  : nil # the number of bytes of disk space that may be used for caching blobs
        cacheCurrentUsed = dataValue['BlobCacheLevel'] ? dataValue['BlobCacheLevel'] : nil # the number of bytes of disk space that is currently used for caching blobs

      else

        puts sprintf( 'UNKNOWN - Cache not available' )
        exit STATE_UNKNOWN
      end

      percent  = ( 100 * cacheCurrentUsed.to_i / cacheMax.to_i ).to_i

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

      puts sprintf( '%s - %s Cache: %d%% used (Used: %s - Max: %s)', status, type, percent, cacheCurrentUsed.to_filesize, cacheMax.to_filesize )
      exit exitCode
    end
  end


end

# ---------------------------------------------------------------------------------------

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: example.rb [options]"

  opts.on('-h', '--host NAME'   , 'Host with running Application')                      { |v| options[:host]  = v }
  opts.on('-a', '--application APP' , 'Name of the running Application')                { |v| options[:application]  = v }
  opts.on('-c', '--cache CACHE' , 'The Cache you want to test [uapi-cache,blob-cache]') { |v| options[:cache] = v }

end.parse!

m = Icinga2Check_CM_Cache.new( options )
