#!/usr/bin/ruby

require_relative '/usr/local/lib/icingachecks.rb'

# ---------------------------------------------------------------------------------------

class Icinga2Check_CM_Cache < Icinga2Check

  def initialize( settings = {} )

    @log = logger()
    @mc  = memcache()

    host         = settings[:host]        ? shortHostname( settings[:host] ) : nil
    application  = settings[:application] ? settings[:application] : nil
    cache        = settings[:cache]       ? settings[:cache]       : nil

    self.check( host, application, cache )

  end

  def check( host, application, type )

    # TODO
    # make it configurable
    warning  = 95
    critical = 98

    # get our bean
    data = MBean.bean( host, application, 'CapConnection' )

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

    puts sprintf( '%s - %s Cache: %d%% used (Used: %s - Max: %s)', status, type, percent, cacheSize.to_filesize, cacheLevel.to_filesize )
    exit exitCode

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
