#!/usr/bin/ruby
#
# encoding: utf-8

require 'optparse'
require 'json'
require 'logger'

require_relative '/usr/local/monitoring/tools.rb'
require_relative '/usr/local/monitoring/mbean.rb'

class Icinga2Check_CM_Feeder

  STATE_OK        = 0
  STATE_warningING   = 1
  STATE_CRITICAL  = 2
  STATE_UNKNOWN   = 3
  STATE_DEPENDENT = 4

  def initialize( settings = {} )

    @host      = settings[:host]    ? settings[:host]   : nil
    @feeder    = settings[:feeder]  ? settings[:feeder] : nil

     @cacheDirectory = '/var/cache/monitoring'

#    logFile = sprintf( '%s/monitoring.log', @logDirectory )
#    file      = File.open( logFile, File::WRONLY | File::APPEND | File::CREAT )
#    file.sync = true
#    @log = Logger.new( file, 'weekly', 1024000 )
    @log = Logger.new( STDOUT )
    @log.level = Logger::DEBUG
    @log.datetime_format = "%Y-%m-%d %H:%M:%S::%3N"
    @log.formatter = proc do |severity, datetime, progname, msg|
      "[#{datetime.strftime(@log.datetime_format)}] #{severity.ljust(5)} : #{msg}\n"
    end

    self.validate()

    # set Cache Directory
    MBean.cacheDirectory( @cacheDirectory )

    case @feeder
    when 'live'
      self.feederStatus()
    when 'preview'
      self.feederStatus()
    when 'content'
      self.contentFeederStatus()
    end

  end

  def validate()

    case @feeder
    when 'live'
      @feederServer = 'caefeeder-live'
    when 'preview'
      @feederServer = 'caefeeder-preview'
    when 'content'
      @feederServer = 'content-feeder'
    else
      puts sprintf( 'Coremedia Feeder - unknown feeder type %s', @feeder )
      exit STATE_CRITICAL
    end

    ip = dnsResolve( @host )

    if( ! isRunning?( ip ) )
      puts sprintf( 'Coremedia Feeder - %s are not available', @host )
      exit STATE_CRITICAL
    end
  end

  def feederStatus()

    warning = 2500
    critical = 10000

    # get our bean
    health = MBean.bean( @host, @feederServer, 'Health' )

#    @log.debug( health )

    healthStatus    = health['status']    ? health['status']    : 500
    healthTimestamp = health['timestamp'] ? health['timestamp'] : nil
    healthValue     = health['value']     ? health['value']     : nil
    healthValue     = healthValue.values.first
    healthy         = ( healthValue != nil &&  healthValue['Healthy'] ) ? healthValue['Healthy'] : false

    if( healthy == true )

      engine = MBean.bean( @host, @feederServer, 'ProactiveEngine' )
      @log.debug( engine )

      engineValue = ( engine != false && engine['value'] ) ? engine['value'] : nil
      engineValue = engineValue.values.first

      @log.debug( engineValue )

      maxEntries     = engineValue['KeysCount']         ? engineValue['KeysCount']         : 0  # Number of (active) keys
      currentEntries = engineValue['ValuesCount']       ? engineValue['ValuesCount']       : 0  # Number of (valid) values. It is less or equal to 'keysCount'

      if( maxEntries == 0 && currentEntries == 0 )

        stateMessage = "no Feederdata. maybe restarting?"
      else

        healthMessage  = "HEALTHY"
        diffEntries    = ( maxEntries - currentEntries ).to_i

        if( maxEntries == currentEntries )
          stateMessage = sprintf( 'all %d Elements feeded', maxEntries )
        else
          stateMessage = sprintf( '%d Elements of %d feeded. (${CountDiff} left)', currentEntries, maxEntries, diffEntries )
        end

        if( diffEntries > critical )
          puts sprintf( 'CRITICAL - %s - %s', healthMessage, stateMessage )
          return STATE_CRITICAL
        elsif( diffEntries > warning || diffEntries == warning )

          puts sprintf( 'warningING - %s - %s', healthMessage, stateMessage )
          return STATE_warningING
        else

          puts sprintf( 'OK - %s - %s', healthMessage, stateMessage )
          return STATE_OK
        end

      end

    else
      puts sprintf( 'CRITICAL - NOT HEALTHY' )
      exit STATE_CRITICAL
    end


#    heartbeat      = engineValue['HeartBeat']         ? engineValue['HeartBeat']         : nil  # The heartbeat of this service: Milliseconds between now and the latest activity. A low value indicates that the service is alive. An constantly increasing value might be caused by a 'sick' or dead service


  end

  def contentFeederStatus()

  end

end


options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: example.rb [options]"

  opts.on('-h', '--host NAME', 'Host with running Application')                            { |v| options[:host]   = v }
  opts.on('-f', '--feeder FEEDER', 'The feeder you want to test [content, live, preview]') { |v| options[:feeder] = v }

end.parse!

puts options

m = Icinga2Check_CM_Feeder.new( options )
