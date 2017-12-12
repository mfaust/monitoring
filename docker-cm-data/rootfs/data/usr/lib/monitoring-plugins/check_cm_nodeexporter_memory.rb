#!/usr/bin/ruby

require 'getoptlong'
require_relative '/usr/local/lib/icingachecks.rb'

def usage(s)
  $stderr.puts(s)
  $stderr.puts("Usage: #{File.basename($0)}: --host <ip|fqdn> --partition  ")
  exit(2)
end

# ---------------------------------------------------------------------------------------

class Icinga2Check_CM_Disk < Icinga2Check

  def initialize( settings )

    super

    host       = settings.dig(:host)
    warning    = settings.dig(:warning).to_i
    critical   = settings.dig(:critical).to_i

    logger.level = Logger::DEBUG

#     logger.debug( "initialize( #{settings} )" )

    # get us only the fqdn
    host       = hostname( host ) || host

    check( host, warning, critical )
  end


  def check( host, warning, critical )

#     logger.debug( "check( #{host}, #{partition}, #{warning}, #{critical} )" )

#    d = @redis.measurements( short: host, application: 'node-exporter' )

    cacheKey     = Storage::RedisClient.cacheKey( host: host, pre: 'result', service: 'node-exporter' )

    result = @redis.get( cacheKey )
    memory = result.dig('memory') unless( result.nil? )

    # {"MemAvailable"=>"3215917056", "MemFree"=>"1288470528", "MemTotal"=>"8335740928", "SwapCached"=>"0", "SwapFree"=>"2684350464", "SwapTotal"=>"2684350464"}

    unless( memory.nil? )

      mem_available    = memory.dig('MemAvailable')
      mem_free         = memory.dig('MemFree')
      mem_total        = memory.dig('MemTotal')
      mem_used         = ( mem_total.to_i - mem_available.to_i )
      mem_used_percent  = ( 100 * mem_used.to_i / mem_total.to_i ).to_i

      swap_total       = memory.dig('SwapTotal')
      swap_cached      = 0
      swap_free        = 0
      swap_used        = 0
      swap_used_percent = 0

      if( swap_total != 0 )

        swap_cached      = memory.dig('SwapCached')
        swap_free        = memory.dig('SwapFree')
        swap_used        = ( swap_total.to_i - swap_free.to_i )

        swap_used_percent = ( 100 * swap_used.to_i / swap_total.to_i ).to_i if( swap_used.to_i > 0 && swap_total.to_i > 0 )
      end

      if( mem_used_percent == warning || mem_used_percent <= warning )
        status    = 'OK'
        exit_code = STATE_OK
      elsif( mem_used_percent >= warning && mem_used_percent <= critical )
        status    = 'WARNING'
        exit_code = STATE_WARNING
      else
        status    = 'CRITICAL'
        exit_code = STATE_CRITICAL
      end

      output = format(
        'Memory - size: %s GiB, used: %s GiB, used percent: %s%%',
        bytes_to_megabytes(mem_total),
        bytes_to_megabytes(mem_used), mem_used_percent
      )

      if( swap_total != 0 )

        if( swap_used_percent == warning || swap_used_percent <= warning )
          status    = 'OK'
          exit_code = STATE_OK
        elsif( swap_used_percent >= warning && swap_used_percent <= critical )
          status    = 'WARNING'
          exit_code = STATE_WARNING
        else
          status    = 'CRITICAL'
          exit_code = STATE_CRITICAL
        end

        output += format(
          '<br>Swap   - size: %s GiB, used: %s GiB, used percent: %s%%',
          bytes_to_megabytes(swap_total),
          bytes_to_megabytes(swap_used), swap_used_percent
        )
      end

      puts output
      exit exit_code

    end
  end

end

# -------------------------------------------------------------------------------------------------

opts = GetoptLong.new(
  [ '--help'      , '-h', GetoptLong::NO_ARGUMENT ],
  [ '--host'      , '-H', GetoptLong::REQUIRED_ARGUMENT ],
  [ '--partition' , '-P', GetoptLong::REQUIRED_ARGUMENT ],
  [ '--warning'   , '-W', GetoptLong::REQUIRED_ARGUMENT ],
  [ '--critical'  , '-C', GetoptLong::REQUIRED_ARGUMENT ],
)

host = nil
warning = 80
critical = 90

begin

  opts.quiet = false
  opts.each do |opt, arg|
    case opt
    when '--help'
      usage("Unknown option: #{ARGV[0].inspect}")
    when '--host'
      host = arg
    when '--warning'
      warning = arg
    when '--critical'
      critical = arg
    end

  end
rescue => e
  puts "Error in arguments"
  puts e.to_s

  exit 1
end

if( host.nil? )
  usage( 'missing host.' )
  exit 1
end

# -------------------------------------------------------------------------------------------------

m = Icinga2Check_CM_Disk.new( host: host, warning: warning, critical: critical )

# EOF
