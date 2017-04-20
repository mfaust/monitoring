#!/usr/bin/ruby

require_relative '/usr/local/lib/icingachecks.rb'

# ---------------------------------------------------------------------------------------

class Icinga2Check_CM_Memory < Icinga2Check

  def initialize( settings = {} )

    super

    host         = settings.dig(:host)
    application  = settings.dig(:application)
    memory       = settings.dig(:memory)

    host         = self.shortHostname( host )

    self.check( host, application, memory )

  end


  def check( host, application, type )

    config   = readConfig( type )
    warning  = config.dig(:warning)  || 90
    critical = config.dig(:critical) || 95

    # get our bean
    data      = @mbean.bean( host, application, 'Memory' )
    dataValue = self.runningOrOutdated( data )

#     dataValue = dataValue.values.first

    case type
    when 'heap-mem'

      memoryType = 'Heap'
      memory     = dataValue.dig('HeapMemoryUsage')

      warning  = 95
      critical = 98

    when 'perm-mem'

      memoryType = 'Perm'
      memory     = dataValue.dig('NonHeapMemoryUsage')

      warning  = 99
      critical = 100

    else

      puts sprintf( 'UNKNOWN - Memory not available' )
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
      status   = 'OK'
      exitCode = STATE_OK
    elsif( percent >= warning && percent <= critical )
      status   = 'WARNING'
      exitCode = STATE_WARNING
    else
      status   = 'CRITICAL'
      exitCode = STATE_CRITICAL
    end

    case type
    when 'heap-mem'
      puts sprintf( '%d%% %s Memory used<br>Max: %s<br>Commited: %s<br>Used: %s', percent, memoryType, max.to_filesize, committed.to_filesize, used.to_filesize )
    else
      puts sprintf( '%d%% %s Memory used<br>Commited: %s<br>Used: %s', percent, memoryType, committed.to_filesize, used.to_filesize )
    end
    exit exitCode

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
