#!/usr/bin/ruby

require_relative '/usr/local/lib/icingachecks.rb'

# ---------------------------------------------------------------------------------------

class Icinga2Check_CM_SequenceNumbers < Icinga2Check

  def initialize( settings = {} )

    super

    mls         = settings.dig(:mls)
    rls         = settings.dig(:rls)

    if( mls.nil? )

      mls = detect_mls(rls)
    end

    hostMls     = self.hostname( mls )
    hostRls     = self.hostname( rls )

    self.check( hostMls, hostRls )

  end


  def check( mls, rls )

    exitCode = STATE_UNKNOWN
    config   = readConfig( 'sequence-number' )

    warning  = config.dig(:warning)  || 300
    critical = config.dig(:critical) || 500

    # get our bean
    mlsData      = @mbean.bean( mls, 'master-live-server', 'Server' )
    mlsDataValue = self.runningOrOutdated( mlsData )

    mlsDataValue      = mlsDataValue.values.first
    mlsSequenceNumber = mlsDataValue.dig('RepositorySequenceNumber' )
    mlsRunLevel       = mlsDataValue.dig('RunLevel').downcase

    # get our bean
    rlsData      = @mbean.bean( rls, 'replication-live-server', 'Replicator' )
    rlsDataValue = self.runningOrOutdated( rlsData )

    rlsDataValue        = rlsDataValue.values.first
    rlsSequenceNumber   = rlsDataValue.dig('LatestCompletedSequenceNumber' )
    rlsControllerState  = rlsDataValue.dig('ControllerState').downcase


    if( mlsRunLevel != 'online' || rlsControllerState != 'running' )

      puts sprintf( 'MLS or RLS are not running' )

      exit STATE_WARNING
    end

    diff = mlsSequenceNumber.to_i - rlsSequenceNumber.to_i

    if( diff == warning || diff <= warning )
      status   = 'OK'
      exitCode = STATE_OK

      puts sprintf( 'RLS and MLS in sync<br>MLS Sequence Number: %s<br>RLS Sequence Number: %s', mlsSequenceNumber.to_i, rlsSequenceNumber.to_i )

      exit exitCode

    elsif( diff >= warning && diff <= critical )
      status   = 'WARNING'
      exitCode = STATE_WARNING
    else
      status   = 'CRITICAL'
      exitCode = STATE_CRITICAL
    end

    puts sprintf( 'RLS are %s Events <b>behind</b> the MLS<br>MLS Sequence Number: %s<br>RLS Sequence Number: %s', diff, mlsSequenceNumber.to_i, rlsSequenceNumber.to_i )

    exit exitCode

  end



  def detect_mls( rls )

    cache_key = format('sequence-mls-%s',rls)
    mls       = @cache.get(cache_key)

    if(mls.nil?)

      bean = @mbean.bean( rls, 'replication-live-server', 'Replicator' )

      if(bean.is_a?(Hash))

        value = bean.dig( 'value' )
        if( !value.nil? )
          value = value.values.first
          mls = value.dig( 'MasterLiveServer', 'host' )

          if(!mls.nil?)
            @cache.set(cache_key, expiresIn: 320 ) { Cache::Data.new( mls ) }
          else
            mls = rls
          end
        end
      end

    end

    mls

  end

end

# ---------------------------------------------------------------------------------------

options = {}

OptionParser.new do |opts|

  opts.banner = "Usage: check_cm_sequencenumbers.rb [options]"

  opts.on( '-r', '--rls NAME'       , 'Host with running Replication-Live-Server')              { |v| options[:rls]  = v }

end.parse!

m = Icinga2Check_CM_SequenceNumbers.new( options )
