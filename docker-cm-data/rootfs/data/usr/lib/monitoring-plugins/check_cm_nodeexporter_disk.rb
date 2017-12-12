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
    partition  = settings.dig(:partition)
    warning    = settings.dig(:warning).to_i
    critical   = settings.dig(:critical).to_i

    # get us only the fqdn
    host       = hostname( host ) || host

    check( host, partition, warning, critical )
  end


  def check( host, partition, warning, critical )

    cacheKey     = Storage::RedisClient.cacheKey( host: host, pre: 'result', service: 'node-exporter' )

    result = @redis.get( cacheKey )
    filesystem = result.dig('filesystem') unless( result.nil? )
    filesystem = filesystem.select { |_y,x| x['mountpoint'] == partition } unless( filesystem.nil? )

    if( filesystem.nil? || (filesystem.is_a?(Hash) && filesystem.count == 0 ) )
      puts format( '<b>Partition %s not found</b>', partition )
      exit STATE_UNKNOWN
    end

    values = filesystem.values.first

    avail = values.dig('avail')
    size  = values.dig('size')

    if( size.to_i > 0 )
      used          = ( size.to_i - avail.to_i )
      used_percent  = ( 100 * used.to_i / size.to_i ).to_i

      if( used_percent == warning || used_percent <= warning )
        status    = 'OK'
        exit_code = STATE_OK
      elsif( used_percent >= warning && used_percent <= critical )
        status    = 'WARNING'
        exit_code = STATE_WARNING
      else
        status    = 'CRITICAL'
        exit_code = STATE_CRITICAL
      end

      puts format(
        'partition %s - size: %s GiB, used: %s GiB, used percent: %s%% | size=%d used=%d percent=%d',
        partition,
        bytes_to_megabytes(size),
        bytes_to_megabytes(used), used_percent,
        size, used, used_percent
      )

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
partition = nil
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
    when '--partition'
      partition = arg
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

if( partition.nil? )
  usage( 'missing partition.' )
  exit 1
end

# -------------------------------------------------------------------------------------------------

m = Icinga2Check_CM_Disk.new( host: host, partition: partition, warning: warning, critical: critical )

# EOF
