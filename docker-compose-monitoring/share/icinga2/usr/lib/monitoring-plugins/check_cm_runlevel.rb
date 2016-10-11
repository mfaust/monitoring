#!/usr/bin/ruby

require_relative '/usr/local/lib/icingachecks.rb'

# ---------------------------------------------------------------------------------------

class Icinga2Check_CM_Runlevel < Icinga2Check

  def initialize( settings = {} )

    @log = logger()
    @mc  = memcache()

    MBean.logger( @log )

    host         = settings[:host]        ? settings[:host]        : nil
    application  = settings[:application] ? settings[:application] : nil

    self.check( host, application )

  end


  def check( host, application )

    # get our bean
    data = MBean.bean( host, application, 'Server' )

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

      beanTimeout,difference = beanTimeout?( dataTimestamp )

      if( beanTimeout == STATE_CRITICAL )
        puts sprintf( 'CRITICAL - last check creation is out of date (%d seconds)', difference )
        exit beanTimeout
      elsif( beanTimeout == STATE_WARNING )
        puts sprintf( 'WARNING - last check creation is out of date (%d seconds)', difference )
        exit beanTimeout
      end

      dataValue     = dataValue.values.first

      runlevel      = dataValue['RunLevel'] ? dataValue['RunLevel'] : false

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

      puts sprintf( '%s - RunLevel in %s Mode)', status, runlevel )
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

m = Icinga2Check_CM_Runlevel.new( options )
