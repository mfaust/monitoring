#!/usr/bin/ruby

require 'time_difference'

require_relative '/usr/local/lib/icingachecks.rb'

# ---------------------------------------------------------------------------------------

class Icinga2Check_CM_Licenses < Icinga2Check

  def initialize( settings = {} )

    @log = logger()
    @mc  = memcache()

    host         = settings[:host]        ? shortHostname( settings[:host] ) : nil
    application  = settings[:application] ? settings[:application] : nil

    self.check( host, application )

  end


  def timeParser( today, finalDate )

    difference = TimeDifference.between( today, finalDate ).in_each_component

    return {
      :years  => difference[:years].round,
      :months => difference[:months].round,
      :weeks  => difference[:weeks].round,
      :days   => difference[:days].round
    }
  end


  def check( host, application )

    # TODO
    # make it configurable
    warning  = 50
    critical = 20

    # get our bean
    data = MBean.bean( host, application, 'Server' )

    dataStatus      = data['status']    ? data['status']    : 500
    dataTimestamp   = data['timestamp'] ? data['timestamp'] : nil
    dataValue       = ( data != nil && data['value'] ) ? data['value'] : nil
    dataValue       = dataValue.values.first

    t               = Date.parse( Time.now().to_s )
    today           = Time.new( t.year, t.month, t.day )

    validUntilHard  = dataValue['LicenseValidUntilHard']    ? dataValue['LicenseValidUntilHard']     : nil

    if( validUntilHard != nil )

      x               = self.timeParser( today, Time.at( validUntilHard / 1000 ) )
      validUntilDays  = x[:days]

      licenseDate     = Time.at( validUntilHard / 1000 ).strftime("%d.%m.%Y")

      if( validUntilDays >= warning || validUntilDays == warning )
        status   = 'OK'
        exitCode = STATE_OK
      elsif( validUntilDays >= critical && validUntilDays <= warning )
        status   = 'WARNING'
        exitCode = STATE_WARNING
      else
        status   = 'CRITICAL'
        exitCode = STATE_CRITICAL
      end

      puts sprintf( '%s - Coremedia License is valid until %s - %d days left', status, licenseDate, validUntilDays )
    else
      puts sprintf( 'UNKNOWN - No valid Coremedia License found' )
      exitCode = STATE_UNKNOWN
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

end.parse!

m = Icinga2Check_CM_Licenses.new( options )
