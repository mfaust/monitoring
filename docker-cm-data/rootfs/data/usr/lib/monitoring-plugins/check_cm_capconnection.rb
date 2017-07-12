#!/usr/bin/ruby

require_relative '/usr/local/lib/icingachecks.rb'

# ---------------------------------------------------------------------------------------

class Icinga2Check_CM_CapConnection < Icinga2Check

  def initialize( settings = {} )

    super

    host         = settings.dig(:host)
    application  = settings.dig(:application)
    memory       = settings.dig(:memory)

    host         = self.hostname( host )

    self.check( host, application, memory )

  end


  def check( host, application, type )

    # get our bean
    data = @mbean.bean( host, application, 'CapConnection' )

    dataValue = self.runningOrOutdated( { host: host, data: data } )

    dataValue = dataValue.values.first

    state = dataValue.dig('Open') || false

    if( state == true )
      status   = 'OK'
      exitCode = STATE_OK
    else
      status   = 'CRITICAL'
      exitCode = STATE_CRITICAL
    end

    puts sprintf( 'Cap Connection <b>%s</b>', state ? 'open' : 'not exists' )
    exit exitCode

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
