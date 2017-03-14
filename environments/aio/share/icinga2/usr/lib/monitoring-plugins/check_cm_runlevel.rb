#!/usr/bin/ruby

require_relative '/usr/local/lib/icingachecks.rb'

# ---------------------------------------------------------------------------------------

class Icinga2Check_CM_Runlevel < Icinga2Check

  def initialize( settings = {} )

    super

    host         = settings.dig(:host)
    application  = settings.dig(:application)

    host         = self.shortHostname( host )

    self.check( host, application )

  end


  def check( host, application )

    # get our bean
    data      = @mbean.bean( host, application, 'Server' )
    dataValue = self.runningOrOutdated( data )

    dataValue = dataValue.values.first
    runlevel  = dataValue.dig('RunLevel') || false

    # in maintenance mode the Server mbean is not available
    case runlevel.downcase
    when 'offline'
      status   = 'CRITICAL'
      exitCode = STATE_CRITICAL
    when 'online'
      status   = 'OK'
      exitCode = STATE_OK
    when 'administration'
      status   = 'WARNING'
      exitCode = STATE_WARNING
    else
      status   = 'CRITICAL'
      exitCode = STATE_CRITICAL
    end

    puts sprintf( '%s - RunLevel in <b>%s</b> Mode', status, runlevel )
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

m = Icinga2Check_CM_Runlevel.new( options )
