#!/usr/bin/ruby

require_relative '/usr/local/lib/icingachecks.rb'

# ---------------------------------------------------------------------------------------

class Icinga2Check_CM_Cache < Icinga2Check

  def initialize( settings = {} )

    super

    host         = settings.dig(:host)
    application  = settings.dig(:application)
    cache        = settings.dig(:cache)

    host         = hostname( host )

    check( host, application, cache )
  end

  def check( host, application, type )

    logger.debug("check( #{host}, #{application}, #{type} )")

    config   = read_config(type)
    warning  = config.dig(:warning)  || 90
    critical = config.dig(:critical) || 95

    # get our bean
    data = @mbean.bean( host, application, 'CapConnection' )

    data_value = running_or_outdated( { host: host, data: data } )
    data_value = data_value.values.first

    case type
    when 'uapi-cache'
      type               = 'UAPI'
      cache_max          = data_value.dig('HeapCacheSize')   # the number of bytes of main memory space that may be used for caching
      cache_current_used = data_value.dig('HeapCacheLevel')  # the number of bytes of main memory space that is currently used for caching
    when 'blob-cache'
      type               = 'BLOB'
      cache_max          = data_value.dig('BlobCacheSize')   # the number of bytes of disk space that may be used for caching blobs
      cache_current_used = data_value.dig('BlobCacheLevel')  # the number of bytes of disk space that is currently used for caching blobs
    else
      puts format( 'UNKNOWN - Cache not available' )
      exit STATE_UNKNOWN
    end

    percent  = ( 100 * cache_current_used.to_i / cache_max.to_i ).to_i

    if( percent == warning || percent <= warning )
      status   = 'OK'
      exit_code = STATE_OK
    elsif( percent >= warning && percent <= critical )
      status   = 'WARNING'
      exit_code = STATE_WARNING
    else
      status   = 'CRITICAL'
      exit_code = STATE_CRITICAL
    end

    puts format(
      '%d%% %s Cache used<br>Max: %s<br>Used %s | max=%d used=%d',
      percent, type, cache_max.to_filesize, cache_current_used.to_filesize, cache_max, cache_current_used,
    )

    exit exit_code
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
