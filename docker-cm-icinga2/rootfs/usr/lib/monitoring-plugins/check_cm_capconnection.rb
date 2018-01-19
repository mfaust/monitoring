#!/usr/bin/ruby

require_relative '/usr/local/lib/icingachecks.rb'

# ---------------------------------------------------------------------------------------

class Icinga2Check_CM_CapConnection < Icinga2Check

  def initialize( settings = {} )

    super

    host         = settings.dig(:host)
    application  = settings.dig(:application)
    memory       = settings.dig(:memory)

    host         = hostname( host )

    check( host, application, memory )
  end


  def check( host, application, type )

    # get our bean
    data = @mbean.bean( host, application, 'CapConnection' )

    data_value = running_or_outdated( host: host, data: data )

    data_value = data_value.values.first

    state = data_value.dig('Open') || false

    if( state == true )
      status   = 'OK'
      exit_code = STATE_OK
    else
      status   = 'CRITICAL'
      exit_code = STATE_CRITICAL
    end

    puts format( 'Cap Connection <b>%s</b>', state ? 'open' : 'not exists' )
    exit exit_code
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
