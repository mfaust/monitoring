#!/usr/bin/ruby
#
# 03.01.2017 - Bodo Schulz
#
#
# v0.7.0

# -----------------------------------------------------------------------------

require 'yaml'

require_relative '../lib/icinga'
require_relative '../lib/message-queue'

# -----------------------------------------------------------------------------

logDirectory     = '/var/log/monitoring'

icingaHost      = ENV['ICINGA_HOST']         ? ENV['ICINGA_HOST']          : 'localhost'
icingaPort      = ENV['ICINGA_PORT']         ? ENV['ICINGA_PORT']          : 5665
icingaApiUser   = ENV['ICINGA_API_USER']     ? ENV['ICINGA_API_USER']      : 'admin'
icingaApiPass   = ENV['ICINGA_API_PASSWORD'] ? ENV['ICINGA_API_PASSWORD']  : nil
mqEnabled       = ENV['MQ_ENABLED']          ? ENV['MQ_ENABLED']           : false
mqHost          = ENV['MQ_HOST']             ? ENV['MQ_HOST']              : 'localhost'
mqPort          = ENV['MQ_PORT']             ? ENV['MQ_PORT']              : 11300
mqQueue         = ENV['MQ_QUEUE']            ? ENV['MQ_QUEUE']             : 'mq-icinga'

config = {
  :icingaHost     => icingaHost,
  :icingaPort     => icingaPort,
  :icingaApiUser  => icingaApiUser,
  :icingaApiPass  => icingaApiPass,
  :mqHost         => mqHost,
  :mqPort         => mqPort,
  :mqQueue        => mqQueue
}

@MQSettings = {
  :beanstalkHost => mqHost,
  :beanstalkPort => mqPort
}
@mqQueue = mqQueue

# ---------------------------------------------------------------------------------------

i = Icinga::Client.new( config )

# ---------------------------------------------------------------------------------------

    # Message-Queue Integration
    #
    #
    #
    def queue()

      c = MessageQueue::Consumer.new( @MQSettings )

      threads = Array.new()

      threads << Thread.new {

        processQueue(
          c.getJobFromTube( @mqQueue )
        )
      }

      threads.each { |t| t.join }

    end


    def processQueue( data = {} )

      if( data.count != 0 )

        logger.info( sprintf( 'process Message from Queue %s: %d', data.dig(:tube), data.dig(:id) ) )
        logger.debug( data )
        #logger.debug( data.dig( :body, 'payload' ) )

        command = data.dig( :body, 'cmd' )     || nil
        node    = data.dig( :body, 'node' )    || nil
        payload = data.dig( :body, 'payload' ) || nil

        if( command == nil )
          logger.error( 'wrong command' )
          logger.error( data )
          return
        end

        if( node == nil || payload == nil )
          logger.error( 'missing node or payload' )
          logger.error( data )
          return
        end

        result = {
          :status  => 400,
          :message => sprintf( 'wrong command detected: %s', command )
        }

        case command
        when 'add'
          logger.info( sprintf( 'add node %s', node ) )

          # TODO
          # check payload!
          # e.g. for 'force' ...
#           result = self.createDashboardForHost( { :host => node, :tags => tags, :overview => overview } )

#           logger.info( result )
        when 'remove'
          logger.info( sprintf( 'remove dashboards for node %s', node ) )
#           result = self.deleteDashboards( { :host => node } )

#           logger.info( result )
        when 'info'
          logger.info( sprintf( 'give dashboards for %s back', node ) )
#           result = self.listDashboards( { :host => node } )
        else
          logger.error( sprintf( 'wrong command detected: %s', command ) )

          result = {
            :status  => 400,
            :message => sprintf( 'wrong command detected: %s', command )
          }

#           logger.info( result )
        end

        result[:request]    = data

#         self.sendMessage( result )
      end

    end


    def sendMessage( data = {} )

    logger.debug( JSON.pretty_generate( data ) )

    p = MessageQueue::Producer.new( @MQSettings )

    job = {
      cmd:  'information',
      from: 'icinga',
      payload: data
    }.to_json

    logger.debug( p.addJob( 'mq-icinga', job ) )

  end

# ---------------------------------------------------------------------------------------

# NEVER FORK THE PROCESS!
# the used supervisord will control all
stop = false

Signal.trap('INT')  { stop = true }
Signal.trap('HUP')  { stop = true }
Signal.trap('TERM') { stop = true }
Signal.trap('QUIT') { stop = true }

until stop
  # do your thing
  if( mqEnabled == true )

    queue()
  else

    i.run()
  end
  sleep( 15 )
end

# -----------------------------------------------------------------------------

# EOF
