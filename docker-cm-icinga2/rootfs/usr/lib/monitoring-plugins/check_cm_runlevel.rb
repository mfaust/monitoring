#!/usr/bin/ruby

require_relative '/usr/local/lib/icingachecks.rb'

# ---------------------------------------------------------------------------------------

class Icinga2Check_CM_Runlevel < Icinga2Check

  def initialize( settings = {} )

    super

    host         = settings.dig(:host)
    application  = settings.dig(:application)

    host         = hostname( host )

    check( host, application )
  end


  def check( host, application )

    # get our bean
    data       = @mbean.bean( host, application, 'Server' )
    data_value = running_or_outdated( { host: host, data: data } )

    data_value = data_value.values.first
    runlevel   = data_value.dig('RunLevel') || false

    # in maintenance mode the Server mbean is not available
    case runlevel.downcase
    when 'offline'
      status    = 'CRITICAL'
      exit_code = STATE_CRITICAL
    when 'online'
      status    = 'OK'
      exit_code = STATE_OK
    when 'administration'
      status    = 'WARNING'
      exit_code = STATE_WARNING
    else
      status    = 'CRITICAL'
      exit_code = STATE_CRITICAL
    end

    puts format( 'RunLevel in <b>%s</b> Mode', runlevel )
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

m = Icinga2Check_CM_Runlevel.new( options )
