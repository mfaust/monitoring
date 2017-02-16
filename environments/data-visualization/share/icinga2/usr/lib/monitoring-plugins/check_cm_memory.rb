#!/usr/bin/ruby

require_relative '/usr/local/lib/icingachecks.rb'

# ---------------------------------------------------------------------------------------

class Icinga2Check_CM_Memory < Icinga2Check

  def initialize( settings = {} )

    super

    host         = settings[:host]        ? settings[:host]        : nil
    application  = settings[:application] ? settings[:application] : nil
    memory       = settings[:memory]      ? settings[:memory]      : nil

    host         = self.shortHostname( host )

    self.check( host, application, memory )

  end


  def check( host, application, type )

    config   = readConfig( type )
    warning  = config[:warning]  ? config[:warning]  : 90
    critical = config[:critical] ? config[:critical] : 95

    # get our bean
    data      = @mbean.bean( host, application, 'Memory' )
    dataValue = self.runningOrOutdated( data )

    dataValue = dataValue.values.first

    case type
    when 'heap-mem'

      memoryType = 'Heap'
      memory     = dataValue['HeapMemoryUsage'] ? dataValue['HeapMemoryUsage'] : nil

      warning  = 95
      critical = 98

    when 'perm-mem'

      memoryType = 'Perm'
      memory     = dataValue['NonHeapMemoryUsage'] ? dataValue['NonHeapMemoryUsage'] : nil

      warning  = 99
      critical = 100

    else

      puts sprintf( 'UNKNOWN - Memory not available' )
      exit STATE_UNKNOWN
    end

    max       = memory['max']       ? memory['max']       : nil
    used      = memory['used']      ? memory['used']      : nil
    committed = memory['committed'] ? memory['committed'] : nil

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
      puts sprintf( '%s - %s Memory: %d%% used (Commited: %s - Used: %s - Max: %s)', status, memoryType, percent, committed.to_filesize, used.to_filesize, max.to_filesize )
    else
      puts sprintf( '%s - %s Memory: %d%% used (Commited: %s - Used: %s)', status, memoryType, percent, committed.to_filesize, used.to_filesize )
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
