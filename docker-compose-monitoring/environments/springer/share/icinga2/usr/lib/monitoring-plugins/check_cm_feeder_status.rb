#!/usr/bin/ruby
#
# encoding: utf-8

require_relative '/usr/local/lib/icingachecks.rb'

# ---------------------------------------------------------------------------------------

class Icinga2Check_CM_Feeder < Icinga2Check

  def initialize( settings = {} )

    @log = logger()
    @mc  = memcache()

    MBean.logger( @log )

    host   = settings[:host]    ? settings[:host]   : nil
    feeder = settings[:feeder]  ? settings[:feeder] : nil

    feederServer = self.validate( feeder )

    case feeder
    when 'live'
      self.feederStatus( host, feederServer )
    when 'preview'
      self.feederStatus( host, feederServer )
    when 'content'
      self.contentFeederStatus( host, feederServer )
    end
  end


  def validate( feeder )

    case feeder
    when 'live'
      feederServer = 'caefeeder-live'
    when 'preview'
      feederServer = 'caefeeder-preview'
    when 'content'
      feederServer = 'content-feeder'
    else
      puts sprintf( 'Coremedia Feeder - unknown feeder type %s', @feeder )
      exit STATE_CRITICAL
    end

    return feederServer

  end


  def feederStatus( host, feederServer )

    config   = readConfig( 'caefeeder' )
    warning  = config[:warning]  ? config[:warning]  : 2500
    critical = config[:critical] ? config[:critical] : 10000

    # get our bean
    health = MBean.bean( host, feederServer, 'Health' )

    if( health == false )
      puts 'CRITICAL - Service not running!?'
      exit STATE_CRITICAL
    else

      healthStatus    = health['status']    ? health['status']    : 500
      healthTimestamp = health['timestamp'] ? health['timestamp'] : nil
      healthValue     = ( health != nil && health['value'] ) ? health['value'] : nil

      if( healthValue == nil )
        puts 'CRITICAL - Service not running!?'
        exit STATE_CRITICAL
      end

      beanTimeout,difference = beanTimeout?( healthTimestamp )

      if( beanTimeout == STATE_CRITICAL )
        puts sprintf( 'CRITICAL - last check creation is out of date (%d seconds)', difference )
        exit beanTimeout
      elsif( beanTimeout == STATE_WARNING )
        puts sprintf( 'WARNING - last check creation is out of date (%d seconds)', difference )
        exit beanTimeout
      end

      healthValue     = healthValue.values.first

      healthy         = ( healthValue != nil &&  healthValue['Healthy'] ) ? healthValue['Healthy'] : false

      if( healthy == true )

        engine      = MBean.bean( host, feederServer, 'ProactiveEngine' )

        engineStatus    = engine['status']    ? engine['status']    : 500
        engineTimestamp = engine['timestamp'] ? engine['timestamp'] : nil
        engineValue     = ( engine != false && engine['value'] ) ? engine['value'] : nil
        engineValue     = engineValue.values.first

        maxEntries     = engineValue['KeysCount']         ? engineValue['KeysCount']         : 0  # Number of (active) keys
        currentEntries = engineValue['ValuesCount']       ? engineValue['ValuesCount']       : 0  # Number of (valid) values. It is less or equal to 'keysCount'
        heartbeat      = engineValue['HeartBeat']         ? engineValue['HeartBeat']         : nil # 1 minute == 60000 ms

        beanTimeout,difference = beanTimeout?( engineTimestamp )

        if( beanTimeout == STATE_CRITICAL )
          puts sprintf( 'CRITICAL - last check creation is out of date (%d seconds)', difference )
          exit beanTimeout
        elsif( beanTimeout == STATE_WARNING )
          puts sprintf( 'WARNING - last check creation is out of date (%d seconds)', difference )
          exit beanTimeout
        end

        if( maxEntries == 0 && currentEntries == 0 )

          stateMessage = "no Feederdata. maybe restarting?"
        else

          if( heartbeat >= 60000 )
            puts sprintf( 'CRITICAL - Feeder Heartbeat is more then 1 minute old (Heartbeat %d ms)', heartbeat )
            exit STATE_CRITICAL
          end

          healthMessage  = "HEALTHY"
          diffEntries    = ( maxEntries - currentEntries ).to_i

          if( maxEntries == currentEntries )
            stateMessage = sprintf( 'all %d Elements feeded (Heartbeat %d ms)', maxEntries, heartbeat )
          else
            stateMessage = sprintf( '%d Elements of %d feeded. (%d left - Heartbeat %d ms)', currentEntries, maxEntries, diffEntries, heartbeat )
          end

          if( diffEntries > critical )
            status   = 'CRITICAL'
            exitCode = STATE_CRITICAL
          elsif( diffEntries > warning || diffEntries == warning )

            status   = 'WARNING'
            exitCode = STATE_WARNING
          else

            status   = 'OK'
            exitCode = STATE_OK
          end

        end

        puts sprintf( '%s - %s - %s', status, healthMessage, stateMessage )
        exit exitCode

      else
        puts sprintf( 'CRITICAL - NOT HEALTHY' )
        exit STATE_CRITICAL
      end
    end

  end


  def contentFeederStatus( host, feederServer )

    config   = readConfig( 'contentfeeder' )
    warning  = config[:warning]  ? config[:warning]  : 2500
    critical = config[:critical] ? config[:critical] : 10000

    data = MBean.bean( host, feederServer, 'Feeder' )

    if( data == false )
      puts 'CRITICAL - Service not running!?'
      exit STATE_CRITICAL
    else

      status    = data['status']    ? data['status']    : 500
      timestamp = data['timestamp'] ? data['timestamp'] : nil
      value     = data['value']     ? data['value']     : nil
      data      = value.values.first

      state = data['State'] ? data['State'] : nil

      if( state == 'running' )

        pendingDocuments = data['CurrentPendingDocuments'] ? data['CurrentPendingDocuments'] : nil
        pendingEvents    = data['PendingEvents']           ? data['PendingEvents']           : nil

        if( pendingDocuments == 0 && pendingDocuments <= warning )

          status   = 'OK'
          exitCode = STATE_OK
        elsif( pendingDocuments >= warning && pendingDocuments <= critical )

          status   = 'WARNING'
          exitCode = STATE_WARNING
        else

          status   = 'CRITICAL'
          exitCode = STATE_CRITICAL
        end

      elsif( state == 'initializing' )

        status   = 'WARNING'
        exitCode = STATE_WARNING
      else

        status   = 'CRITICAL'
        exitCode = STATE_CRITICAL
      end

      puts sprintf( '%s - Pending Documents: %d , Pending Events: %d', status, pendingDocuments, pendingEvents )
      exit exitCode
    end
  end

end

# ---------------------------------------------------------------------------------------

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: example.rb [options]"

  opts.on('-h', '--host NAME', 'Host with running Application')                            { |v| options[:host]   = v }
  opts.on('-f', '--feeder FEEDER', 'The feeder you want to test [content, live, preview]') { |v| options[:feeder] = v }

end.parse!

# puts options

m = Icinga2Check_CM_Feeder.new( options )
