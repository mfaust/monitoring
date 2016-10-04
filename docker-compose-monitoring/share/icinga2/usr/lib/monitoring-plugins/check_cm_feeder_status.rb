#!/usr/bin/ruby

require 'optparse'
require 'json'
require 'logger'

require_relative '/usr/local/lib/mbean.rb'

class Icinga2Check_CM_Feeder

  STATE_OK        = 0
  STATE_WARNING   = 1
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

    @memcacheHost     = ENV['MEMCACHE_HOST'] ? ENV['MEMCACHE_HOST'] : nil
    @memcachePort     = ENV['MEMCACHE_PORT'] ? ENV['MEMCACHE_PORT'] : nil
    @supportMemcache  = false

    MBean.logger( @log )

    if( @memcacheHost != nil && @memcachePort != nil )

      # enable Memcache Support

      require 'dalli'

      memcacheOptions = {
        :compress   => true,
        :namespace  => 'monitoring',
        :expires_in => 0
      }

      @mc = Dalli::Client.new( sprintf( '%s:%s', @memcacheHost, @memcachePort ), memcacheOptions )

      @supportMemcache = true

      MBean.memcache( @memcacheHost, @memcachePort )
    end

    self.validate()

    case @feeder
    when 'live'
      self.feederStatus()
    when 'preview'
      self.feederStatus()
    when 'content'
      self.contentFeederStatus()
    end

  end

  def shortHostname( hostname )

    shortHostname   = hostname.split( '.' ).first

    return shortHostname

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

    @host = self.shortHostname( @host )

  end


  def feederStatus()

    # TODO
    # make it configurable
    warning  = 2500
    critical = 10000

    # get our bean
    health = MBean.bean( @host, @feederServer, 'Health' )

#     @log.debug( health )

    healthStatus    = health['status']    ? health['status']    : 500
    healthTimestamp = health['timestamp'] ? health['timestamp'] : nil
    healthValue     = ( health != nil && health['value'] ) ? health['value'] : nil
    healthValue     = healthValue.values.first

    healthy         = ( healthValue != nil &&  healthValue['Healthy'] ) ? healthValue['Healthy'] : false

    if( healthy == true )

      engine      = MBean.bean( @host, @feederServer, 'ProactiveEngine' )

      engineStatus    = engine['status']    ? engine['status']    : 500
      engineTimestamp = engine['timestamp'] ? engine['timestamp'] : nil
      engineValue     = ( engine != false && engine['value'] ) ? engine['value'] : nil
      engineValue     = engineValue.values.first

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
          exit STATE_CRITICAL
        elsif( diffEntries > warning || diffEntries == warning )

          puts sprintf( 'WARNING - %s - %s', healthMessage, stateMessage )
          exit STATE_WARNING
        else

          puts sprintf( 'OK - %s - %s', healthMessage, stateMessage )
          exit STATE_OK
        end

      end

    else
      puts sprintf( 'CRITICAL - NOT HEALTHY' )
      exit STATE_CRITICAL
    end

  end


  def contentFeederStatus()

    # TODO
    # make it configurable
    warning  = 2500
    critical = 10000

    data = MBean.bean( @host, @feederServer, 'Feeder' )

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


options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: example.rb [options]"

  opts.on('-h', '--host NAME', 'Host with running Application')                            { |v| options[:host]   = v }
  opts.on('-f', '--feeder FEEDER', 'The feeder you want to test [content, live, preview]') { |v| options[:feeder] = v }

end.parse!

# puts options

m = Icinga2Check_CM_Feeder.new( options )
