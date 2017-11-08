#!/usr/bin/ruby

require_relative '/usr/local/lib/icingachecks.rb'

# ---------------------------------------------------------------------------------------

class Icinga2Check_CM_SequenceNumbers < Icinga2Check

  def initialize( settings = {} )

    super

    rls       = settings.dig(:rls)
    mls       = settings.dig(:mls)

    hostRls   = self.hostname( rls )
    hostMls   = self.hostname( mls )

#     unless( mls.nil? )
#       hostMls = self.hostname( mls )
#     else
#       mls     = auto_detect_mls(rls)
#       hostMls = nil if( mls.nil? )
#     end

    self.check( hostMls, hostRls )

  end


  def check( mls, rls )

    exitCode = STATE_UNKNOWN
    config   = readConfig( 'sequence-number' )

    warning  = config.dig(:warning)  || 300
    critical = config.dig(:critical) || 500

    if( mls.nil? )

      puts sprintf( 'please, give me an Master Live Server!' )
      exit exitCode
    end

    # get our bean
    rlsData      = @mbean.bean( rls, 'replication-live-server', 'Replicator' )
    mlsData      = @mbean.bean( mls, 'master-live-server', 'Server' )

    logger.debug( "rls data: #{rlsData.class.to_s}" )
    logger.debug( "mls data: #{mlsData.class.to_s}" )

    if ( rlsData == nil || rlsData == false ) && ( mlsData == nil || mlsData == false )

      puts sprintf( 'RLS or MLS has no data' )
      exit STATE_WARNING
    end

    mlsDataValue = self.runningOrOutdated( { host: mls, data: mlsData } )

#    mlsDataValue = self.runningOrOutdated( mlsData )

    mlsDataValue      = mlsDataValue.values.first
    mlsSequenceNumber = mlsDataValue.dig('RepositorySequenceNumber' )
    mlsRunLevel       = mlsDataValue.dig('RunLevel').downcase

    # get our bean

    rlsDataValue = self.runningOrOutdated( { host: rls, data: rlsData } )
#    rlsDataValue = self.runningOrOutdated( rlsData )

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

      puts format(
        'RLS and MLS in sync<br>MLS Sequence Number: %s<br>RLS Sequence Number: %s | diff=%d mls_seq_nr=%d rls_seq_nr=%d',
        mlsSequenceNumber.to_i, rlsSequenceNumber.to_i,
        diff, mlsSequenceNumber.to_i, rlsSequenceNumber.to_i
      )

      exit exitCode

    elsif( diff >= warning && diff <= critical )
      status   = 'WARNING'
      exitCode = STATE_WARNING
    else
      status   = 'CRITICAL'
      exitCode = STATE_CRITICAL
    end

    puts format(
      'RLS are %s Events <b>behind</b> the MLS<br>MLS Sequence Number: %s<br>RLS Sequence Number: %s | diff=%d mls_seq_nr=%d rls_seq_nr=%d',
      diff, mlsSequenceNumber.to_i, rlsSequenceNumber.to_i,
      diff, mlsSequenceNumber.to_i, rlsSequenceNumber.to_i
    )

    exit exitCode

  end



#   # TODO
#   # move this ASAP to icinga-client!
#   #
#   def auto_detect_mls( rls )
#
#     cache_key = format('sequence-mls-%s',rls)
#     mls       = @redis.get(cache_key)
#
#     if(mls.nil?)
#
#       bean = @mbean.bean( rls, 'replication-live-server', 'Replicator' )
#
#       if(bean.is_a?(Hash))
#
#         value = bean.dig( 'value' )
#         unless( value.nil? )
#
#           value = value.values.first
#           mls   = value.dig( 'MasterLiveServer', 'host' )
#
#           if( mls.nil? )
#             logger.error( 'no MasterLiveServer Data found' )
#             return nil
#           else
#             @redis.set(cache_key,mls,320)
#           end
#         end
#       end
#     end
#
#     mls
#   end

end

# ---------------------------------------------------------------------------------------

options = {}

OptionParser.new do |opts|

  opts.banner = "Usage: check_cm_sequencenumbers.rb [options]"

  opts.on( '-r', '--rls NAME'       , 'Host with running Replication-Live-Server')              { |v| options[:rls]  = v }
  opts.on( '-m', '--mls NAME'       , 'Host with running Master-Live-Server')                   { |v| options[:mls]  = v }

end.parse!

m = Icinga2Check_CM_SequenceNumbers.new( options )
