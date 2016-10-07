#!/usr/bin/ruby

require_relative '/usr/local/lib/icingachecks.rb'

# ---------------------------------------------------------------------------------------

class Icinga2Check_CM_CapConnection < Icinga2Check

  def initialize( settings = {} )

    @log = logger()
    @mc  = memcache()

    MBean.logger( @log )

    host         = settings[:host]        ? shortHostname( settings[:host] ) : nil
    application  = settings[:application] ? settings[:application] : nil
    memory       = settings[:memory]      ? settings[:memory]      : nil

    self.check( host, application, memory )

  end


  def check( host, application, type )

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

      state = dataValue['Open'] ? dataValue['Open'] : false

      if( state == true )
        status   = 'OK'
        exitCode = STATE_OK
      else
        status   = 'CRITICAL'
        exitCode = STATE_CRITICAL
      end

      puts sprintf( '%s - Cap Connection %s)', status, state ? 'Open' : 'not existst' )
      exit exitCode
    end
  end

end

# ---------------------------------------------------------------------------------------

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: example.rb [options]"

  opts.on('-h', '--host NAME'       , 'Host with running Application')                   { |v| options[:host]  = v }
  opts.on('-a', '--application APP' , 'Name of the running Application')                 { |v| options[:application]  = v }

end.parse!

m = Icinga2Check_CM_CapConnection.new( options )
