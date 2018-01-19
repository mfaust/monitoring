#!/usr/bin/ruby

require_relative '/usr/local/lib/icingachecks.rb'

# ---------------------------------------------------------------------------------------

class Icinga2Check_CM_SequenceNumbers < Icinga2Check

  def initialize( settings = {} )

    super

    logger.level = Logger::DEBUG

    rls       = settings.dig(:rls)
    mls       = settings.dig(:mls)

    host_rls   = hostname( rls )
    host_mls   = hostname( mls )

#     unless( mls.nil? )
#       host_mls = hostname( mls )
#     else
#       mls     = auto_detect_mls(rls)
#       host_mls = nil if( mls.nil? )
#     end

    check( host_mls, host_rls )

  end


  def check( mls, rls )

    exit_code = STATE_UNKNOWN

    if( mls.nil? )
      puts format( 'please, give me an Master Live Server!' )
      exit exit_code
    end

    config   = read_config( 'sequence-number' )
    warning  = config.dig(:warning)  || 300
    critical = config.dig(:critical) || 500

    # get our bean
    rls_data      = @mbean.bean( rls, 'replication-live-server', 'Replicator' )
    mls_data      = @mbean.bean( mls, 'master-live-server', 'Server' )

    logger.debug( "rls data: #{rls_data.class.to_s}" )
    logger.debug( "mls data: #{mls_data.class.to_s}" )

    if ( rls_data == nil || rls_data == false ) && ( mls_data == nil || mls_data == false )

      puts format( 'RLS or MLS has no data' )
      exit STATE_WARNING
    end

    mls_data_value = running_or_outdated( { host: mls, data: mls_data } )

#    mls_data_value = running_or_outdated( mls_data )

    mls_data_value      = mls_data_value.values.first
    mls_sequence_number = mls_data_value.dig('RepositorySequenceNumber' )
    mls_runLevel       = mls_data_value.dig('RunLevel').downcase

    # get our bean

    rls_data_value = running_or_outdated( { host: rls, data: rls_data } )
#    rls_data_value = running_or_outdated( rls_data )

    rls_data_value        = rls_data_value.values.first
    rls_sequence_number   = rls_data_value.dig('LatestCompletedSequenceNumber' )
    rls_controller_state  = rls_data_value.dig('ControllerState').downcase


    if( mls_runLevel != 'online' || rls_controller_state != 'running' )

      puts format( 'MLS or RLS are not running' )

      exit STATE_WARNING
    end

    diff = mls_sequence_number.to_i - rls_sequence_number.to_i

    if( diff == warning || diff <= warning )
      status   = 'OK'
      exit_code = STATE_OK

      puts format(
        'RLS and MLS in sync<br>MLS Sequence Number: %s<br>RLS Sequence Number: %s | diff=%d mls_seq_nr=%d rls_seq_nr=%d',
        mls_sequence_number.to_i, rls_sequence_number.to_i,
        diff, mls_sequence_number.to_i, rls_sequence_number.to_i
      )

      exit exit_code

    elsif( diff >= warning && diff <= critical )
      status   = 'WARNING'
      exit_code = STATE_WARNING
    else
      status   = 'CRITICAL'
      exit_code = STATE_CRITICAL
    end

    puts format(
      'RLS are %s Events <b>behind</b> the MLS<br>MLS Sequence Number: %s<br>RLS Sequence Number: %s | diff=%d mls_seq_nr=%d rls_seq_nr=%d',
      diff, mls_sequence_number.to_i, rls_sequence_number.to_i,
      diff, mls_sequence_number.to_i, rls_sequence_number.to_i
    )

    exit exit_code
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
