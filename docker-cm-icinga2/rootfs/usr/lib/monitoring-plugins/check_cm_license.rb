#!/usr/bin/ruby

require_relative '/usr/local/lib/icingachecks.rb'

# ---------------------------------------------------------------------------------------

class Icinga2Check_CM_Licenses < Icinga2Check

  def initialize( settings = {} )

    super
    host         = settings.dig(:host)
    application  = settings.dig(:application)

    host         = hostname( host )

    check( host, application )
  end


  def check( host, application )

    config   = read_config( 'license' )
    warning  = config.dig(:warning)  || 50
    critical = config.dig(:critical) || 20

    # get our bean
    data      = @mbean.bean( host, application, 'Server' )
    data_value = running_or_outdated( { host: host, data: data } )

    data_value = data_value.values.first

    t               = Date.parse( Time.now().to_s )
    today           = Time.new( t.year, t.month, t.day )

    valid_until_hard  = data_value.dig('LicenseValidUntilHard')

    if( valid_until_hard != nil )

      x                = time_difference( today, Time.at( valid_until_hard / 1000 ) )
      valid_until_days = x[:days]
      license_date     = Time.at( valid_until_hard / 1000 ).strftime('%d.%m.%Y')

      if( valid_until_days >= warning || valid_until_days == warning )
        status   = 'OK'
        exit_code = STATE_OK
      elsif( valid_until_days >= critical && valid_until_days <= warning )
        status   = 'WARNING'
        exit_code = STATE_WARNING
      else
        status   = 'CRITICAL'
        exit_code = STATE_CRITICAL
      end

      puts format(
        '<b>%d days left</b><br>CoreMedia License is valid until %s | valid=%d warning=%d critical=%d',
        valid_until_days, license_date, valid_until_days,warning, critical
      )
    else
      puts format( 'UNKNOWN - No valid CoreMedia License found' )
      exit_code = STATE_UNKNOWN
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

end.parse!

m = Icinga2Check_CM_Licenses.new( options )
