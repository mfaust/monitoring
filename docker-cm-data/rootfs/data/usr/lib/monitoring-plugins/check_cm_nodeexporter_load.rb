#!/usr/bin/ruby

require 'getoptlong'
require_relative '/usr/local/lib/icingachecks.rb'

def usage(s)
  $stderr.puts(s)
  $stderr.puts("Usage: #{File.basename($0)}: --host <ip|fqdn> --partition  ")
  exit(2)
end

# ---------------------------------------------------------------------------------------

class Icinga2Check_CM_Load < Icinga2Check

  def initialize( settings )

    super

    host       = settings.dig(:host)
    warning    = settings.dig(:warning).to_f
    critical   = settings.dig(:critical).to_f

    # get us only the fqdn
    host       = hostname( host ) || host

    check( host, warning, critical )
  end


  def check( host, warning, critical )

    logger.debug( "check( #{host}, #{warning}, #{critical} )" )

    cacheKey     = Storage::RedisClient.cacheKey( host: host, pre: 'result', service: 'node-exporter' )

    result = @redis.get( cacheKey )

    cpu  = result.dig('cpu') unless( result.nil? )
    load = result.dig('load') unless( result.nil? )

    # "cpu"=>{
    #    "cpu0"=>{"guest"=>"0", "guest_nice"=>"0", "idle"=>"7167.66", "iowait"=>"2.79", "irq"=>"0", "nice"=>"0", "softirq"=>"103.74", "steal"=>"23.16", "system"=>"202.15", "user"=>"480.69"},
    #    "cpu1"=>{"guest"=>"0", "guest_nice"=>"0", "idle"=>"7537.06", "iowait"=>"3.6", "irq"=>"0", "nice"=>"0.02", "softirq"=>"2.68", "steal"=>"24.24", "system"=>"42.17", "user"=>"416.54"}, "cpu2"=>{"guest"=>"0", "guest_nice"=>"0", "idle"=>"7527.17", "iowait"=>"4.05", "irq"=>"0", "nice"=>"0", "softirq"=>"2.05", "steal"=>"24.66", "system"=>"37.25", "user"=>"425.06"}
    # }
    # "load"=>{"shortterm"=>"0.16", "longterm"=>"0.23", "midterm"=>"0.24"}


    if( load.nil? || (load.is_a?(Hash) && load.count == 0 ) )
      puts '<b>No load value found</b>'
      exit STATE_UNKNOWN
    end

    short = load.dig('shortterm').to_f
    mid   = load.dig('midterm').to_f
    long  = load.dig('longterm').to_f

    cpu_count = cpu.keys.count

    if( short == warning || short <= warning )
      status    = 'OK'
      exit_code = STATE_OK
    elsif( short >= warning && short <= critical )
      status    = 'WARNING'
      exit_code = STATE_WARNING
    else
      status    = 'CRITICAL'
      exit_code = STATE_CRITICAL
    end

    puts format( 'load: %s, %s, %s (%s cpu%s)', short, mid, long, cpu_count, cpu_count > 1 ? 's' : nil )
    exit exit_code
  end

end

# -------------------------------------------------------------------------------------------------

opts = GetoptLong.new(
  [ '--help'      , '-h', GetoptLong::NO_ARGUMENT ],
  [ '--host'      , '-H', GetoptLong::REQUIRED_ARGUMENT ],
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

m = Icinga2Check_CM_Load.new( host: host, warning: warning, critical: critical )

# EOF
