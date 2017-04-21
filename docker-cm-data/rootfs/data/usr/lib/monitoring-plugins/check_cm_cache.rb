#!/usr/bin/ruby

require_relative '/usr/local/lib/icingachecks.rb'

# ---------------------------------------------------------------------------------------

class Icinga2Check_CM_Cache < Icinga2Check

  def initialize( settings = {} )

    super

    host         = settings.dig(:host)
    application  = settings.dig(:application)
    cache        = settings.dig(:cache)

    host         = self.shortHostname( host )

    self.check( host, application, cache )

  end

  def check( host, application, type )

    config   = readConfig( type )

    warning  = config.dig(:warning)  || 90
    critical = config.dig(:critical) || 95

    # get our bean
    data = @mbean.bean( host, application, 'CapConnection' )

    dataValue = self.runningOrOutdated( data )

    dataValue = dataValue.values.first

    case type
    when 'uapi-cache'
      type             = 'UAPI'
      cacheMax         = dataValue.dig('HeapCacheSize')   # the number of bytes of main memory space that may be used for caching
      cacheCurrentUsed = dataValue.dig('HeapCacheLevel')  # the number of bytes of main memory space that is currently used for caching

    when 'blob-cache'
      type             = 'BLOB'
      cacheMax         = dataValue.dig('BlobCacheSize')   # the number of bytes of disk space that may be used for caching blobs
      cacheCurrentUsed = dataValue.dig('BlobCacheLevel')  # the number of bytes of disk space that is currently used for caching blobs

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

    puts sprintf( '%d%% %s Cache used<br>Max: %s<br>Used %s', percent, type, cacheMax.to_filesize, cacheCurrentUsed.to_filesize )

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
