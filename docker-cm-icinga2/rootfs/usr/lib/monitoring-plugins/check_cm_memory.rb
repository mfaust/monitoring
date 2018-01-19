#!/usr/bin/ruby

require_relative '/usr/local/lib/icingachecks.rb'

# ---------------------------------------------------------------------------------------

class Icinga2Check_CM_Memory < Icinga2Check

  def initialize( settings = {} )

    super

    host         = settings.dig(:host)
    application  = settings.dig(:application)
    memory       = settings.dig(:memory)

    host         = hostname( host )

    check( host, application, memory )
  end


  def check( host, application, type )

    config   = read_config( type )
    warning  = config.dig(:warning)  || 90
    critical = config.dig(:critical) || 95

    # get our bean
    data       = @mbean.bean( host, application, 'Memory' )
    data_value = running_or_outdated( { host: host, data: data } )

#     data_value = data_value.values.first

    case type
    when 'heap-mem'
      memory_type = 'Heap'
      memory      = data_value.dig('HeapMemoryUsage')
      warning     = 95
      critical    = 98
    when 'perm-mem'
      memory_type = 'Perm'
      memory      = data_value.dig('NonHeapMemoryUsage')
      warning     = 99
      critical    = 100
    else
      puts format( 'UNKNOWN - Memory not available' )
      exit STATE_UNKNOWN
    end

    max       = memory.dig('max')
    used      = memory.dig('used')
    committed = memory.dig('committed')

    if( max != -1 )
      percent  = ( 100 * used.to_i / max.to_i ).to_i
    else
      percent  = ( 100 * used.to_i / committed.to_i ).to_i
    end

    if( percent == warning || percent <= warning )
      status    = 'OK'
      exit_code = STATE_OK
    elsif( percent >= warning && percent <= critical )
      status    = 'WARNING'
      exit_code = STATE_WARNING
    else
      status    = 'CRITICAL'
      exit_code = STATE_CRITICAL
    end

    case type
    when 'heap-mem'
      puts format(
        '%d%% %s Memory used<br>Max: %s<br>Committed: %s<br>Used: %s | max=%d committed=%d used=%d',
        percent, memory_type, max.to_filesize, committed.to_filesize, used.to_filesize,
        max, committed, used
      )
    else
      puts format(
        '%d%% %s Memory used<br>Commited: %s<br>Used: %s | committed=%d used=%d',
        percent, memory_type, committed.to_filesize, used.to_filesize,
        committed, used
      )
    end
    exit exit_code
  end

end

# ---------------------------------------------------------------------------------------

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: example.rb [options]"

  opts.on('-h', '--host NAME'       , 'Host with running Application')                   { |v| options[:host]  = v }
  opts.on('-a', '--application APP' , 'Name of the running Application')                 { |v| options[:application]  = v }
  opts.on('-c', '--memory MEMORY'   , 'The Memory you want to test [heap-mem,perm-mem]') { |v| options[:memory] = v }

end.parse!

m = Icinga2Check_CM_Memory.new( options )
