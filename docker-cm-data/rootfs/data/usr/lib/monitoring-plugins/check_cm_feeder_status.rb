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

    host         = hostname( host )

    feeder_server = validate( feeder )

    case feeder
    when 'live'
      cae_feeder_status( host, feeder_server )
    when 'preview'
      cae_feeder_status( host, feeder_server )
    when 'content'
      content_feeder_status( host, feeder_server )
    end
  end


  def validate( feeder )

    case feeder
    when 'live'
      feeder_server = 'caefeeder-live'
    when 'preview'
      feeder_server = 'caefeeder-preview'
    when 'content'
      feeder_server = 'content-feeder'
    else
      puts format( 'CoreMedia Feeder - unknown feeder type %s', feeder )
      exit STATE_CRITICAL
    end

    feeder_server
  end


  def cae_feeder_status( host, feeder_server )

    config   = read_config( 'caefeeder' )
    warning  = config.dig(:warning)  || 2500
    critical = config.dig(:critical) || 10000

    # get our bean
    health      = @mbean.bean( host, feeder_server, 'Health' )
    engine      = @mbean.bean( host, feeder_server, 'ProactiveEngine' )

    health_value = running_or_outdated( host: host, data: health )
    health_value = health_value.values.first

    healthy     = ( health_value != nil &&  health_value['Healthy'] ) ? health_value['Healthy'] : false

    if( healthy == true )

      health_message  = 'HEALTHY'

      engine_value = running_or_outdated( host: host, data: engine )
      engine_value = engine_value.values.first

#       logger.debug( JSON.pretty_generate( engine_value ) )

      max_entries            = engine_value.dig('KeysCount')   || 0  # Number of (active) keys
      current_entries        = engine_value.dig('ValuesCount') || 0  # Number of (valid) values. It is less or equal to 'keysCount'
      heartbeat              = engine_value.dig('HeartBeat')         # 1 minute == 60000 ms

      if( max_entries == 0 && current_entries == 0 )

        status       = 'UNKNOWN'
        puts format(
          '%d Elements for Feeder available. This feeder is maybe restarting?',
          max_entries
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

        diff_entries    = ( max_entries - current_entries ).to_i

        if( diff_entries > critical )
          status   = 'CRITICAL'
          exit_code = STATE_CRITICAL
        elsif( diff_entries > warning || diff_entries == warning )

          status   = 'WARNING'
          exit_code = STATE_WARNING
        else

          status   = 'OK'
          exit_code = STATE_OK
        end

        if( max_entries == current_entries )

          puts format(
            'all %d Elements feeded<br>Heartbeat %d ms | max=%s current=%d diff=%d heartbeat=%d',
            max_entries, heartbeat,
            max_entries, current_entries, diff_entries, heartbeat
          )
          exit exit_code
        else

          puts format(
            '%d Elements of %d feeded.<br>%d elements left<br>Heartbeat %d ms | max=%s current=%d diff=%d heartbeat=%d',
            current_entries, max_entries, diff_entries, heartbeat,
            max_entries, current_entries, diff_entries, heartbeat
          )
          exit exit_code
        end

      end

    else
      puts format( 'CRITICAL - NOT HEALTHY' )
      exit STATE_CRITICAL
    end

  end


  def content_feeder_status( host, feeder_server )

    config   = read_config( 'contentfeeder' )
    warning  = config.dig(:warning)  || 2500
    critical = config.dig(:critical) || 10000

    data       = @mbean.bean( host, feeder_server, 'Feeder' )
    data_value = running_or_outdated( host: host, data: data )
    data_value = data_value.values.first
    state      = data_value.dig('State')

    if( state.downcase == 'running' )

      pending_documents = data_value.dig('CurrentPendingDocuments')
      pending_events    = data_value.dig('PendingEvents')

      if( pending_documents == 0 && pending_documents <= warning )

        status   = 'OK'
        exit_code = STATE_OK
      elsif( pending_documents >= warning && pending_documents <= critical )

        status   = 'WARNING'
        exit_code = STATE_WARNING
      else

        status   = 'CRITICAL'
        exit_code = STATE_CRITICAL
      end

      puts format(
        'Pending Documents: %d<br>Pending Events: %d | pending_documents=%d pending_events=%d',
        pending_documents, pending_events,
        pending_documents, pending_events
      )

    elsif( state.downcase == 'initializing' )

      status   = 'WARNING'
      exit_code = STATE_WARNING

      puts format( 'Feeder are in <b>%s</b> state', state )
    else

      status   = 'CRITICAL'
      exit_code = STATE_CRITICAL

      puts 'Feeder are in unknown state'
    end

    exit exit_code
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
