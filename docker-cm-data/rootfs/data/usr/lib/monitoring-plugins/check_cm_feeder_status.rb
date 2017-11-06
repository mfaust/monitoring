#!/usr/bin/ruby
#
# encoding: utf-8

require_relative '/usr/local/lib/icingachecks.rb'

# ---------------------------------------------------------------------------------------

class Icinga2Check_CM_Feeder < Icinga2Check

  def initialize( settings = {} )

    super

    host   = settings.dig(:host)
    feeder = settings.dig(:feeder)

    host         = self.hostname( host )

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
      puts sprintf( 'CoreMedia Feeder - unknown feeder type %s', feeder )
      exit STATE_CRITICAL
    end

    return feederServer

  end


  def feederStatus( host, feederServer )

    config   = readConfig( 'caefeeder' )
    warning  = config.dig(:warning)  || 2500
    critical = config.dig(:critical) || 10000

    # get our bean
    health      = @mbean.bean( host, feederServer, 'Health' )
    engine      = @mbean.bean( host, feederServer, 'ProactiveEngine' )

    healthValue = self.runningOrOutdated( { host: host, data: health } )
    healthValue = healthValue.values.first

    healthy     = ( healthValue != nil &&  healthValue['Healthy'] ) ? healthValue['Healthy'] : false

    if( healthy == true )

      healthMessage  = 'HEALTHY'

      engineValue = self.runningOrOutdated( { host: host, data: engine } )
      engineValue = engineValue.values.first

#       logger.debug( JSON.pretty_generate( engineValue ) )

      maxEntries            = engineValue.dig('KeysCount')   || 0  # Number of (active) keys
      currentEntries        = engineValue.dig('ValuesCount') || 0  # Number of (valid) values. It is less or equal to 'keysCount'
      heartbeat             = engineValue.dig('HeartBeat')         # 1 minute == 60000 ms

      if( maxEntries == 0 && currentEntries == 0 )

        status       = 'UNKNOWN'
        puts format(
          '%d Elements for Feeder available. This feeder is maybe restarting?',
          maxEntries
        )
        exit STATE_UNKNOWN
      else

        if( heartbeat >= 60000 )
          puts format(
            'Feeder Heartbeat is more then 1 minute old<br>Heartbeat %d ms',
            heartbeat
          )
          exit STATE_CRITICAL
        end

        diffEntries    = ( maxEntries - currentEntries ).to_i

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

        if( maxEntries == currentEntries )

          puts format(
            'all %d Elements feeded<br>Heartbeat %d ms | max=%s current=%d diff=%d heartbeat=%d',
            maxEntries, heartbeat,
            maxEntries, currentEntries, diffEntries, heartbeat
          )
          exit exitCode
        else

          puts format(
            '%d Elements of %d feeded.<br>%d elements left<br>Heartbeat %d ms | max=%s current=%d diff=%d heartbeat=%d',
            currentEntries, maxEntries, diffEntries, heartbeat,
            maxEntries, currentEntries, diffEntries, heartbeat
          )
          exit exitCode
        end

      end

    else
      puts sprintf( 'CRITICAL - NOT HEALTHY' )
      exit STATE_CRITICAL
    end

  end


  def contentFeederStatus( host, feederServer )

    config   = readConfig( 'contentfeeder' )
    warning  = config.dig(:warning)  || 2500
    critical = config.dig(:critical) || 10000

    data      = @mbean.bean( host, feederServer, 'Feeder' )
    dataValue = self.runningOrOutdated( { host: host, data: data } )
    dataValue = dataValue.values.first
    state     = dataValue.dig('State')

    if( state == 'running' )

      pendingDocuments = dataValue.dig('CurrentPendingDocuments')
      pendingEvents    = dataValue.dig('PendingEvents')

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

      puts format(
        'Pending Documents: %d<br>Pending Events: %d | pending_documents=%d pending_events=%d',
        pendingDocuments, pendingEvents,
        pendingDocuments, pendingEvents
      )

    elsif( state == 'initializing' )

      status   = 'WARNING'
      exitCode = STATE_WARNING

      puts sprintf( 'Feeder are in <b>%s</b> state', state )
    else

      status   = 'CRITICAL'
      exitCode = STATE_CRITICAL

      puts 'Feeder are in unknown state'
    end

    exit exitCode

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
