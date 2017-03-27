#!/usr/bin/ruby
#
#  28.08.2016 - bodsch
#
#
# v1.3.0
# -----------------------------------------------------------------------------

require 'rest-client'
require 'uri'
require 'time'

require_relative 'logging'
require_relative 'message-queue'
require_relative 'graphite/annotations'
require_relative 'graphite/queue'

# -------------------------------------------------------------------------------------------------------------------

module Graphite

  class Client

    include Logging

    include Graphite::Annotions
    include Graphite::Queue

    def initialize( params = {} )

      graphiteHost      = params.dig(:graphiteHost)     || 'localhost'
      graphiteHttpPort  = params.dig(:graphiteHttpPort) || 8081
      graphitePort      = params.dig(:graphitePort)     || 2003
      graphitePath      = params.dig(:graphitePath)
      mqHost            = params.dig(:mqHost)           || 'localhost'
      mqPort            = params.dig(:mqPort)           || 11300
      @mqQueue          = params.dig(:mqQueue)          || 'mq-graphite'

      @graphiteURI      = sprintf( 'http://%s:%s%s', graphiteHost, graphiteHttpPort, graphitePath )

      @MQSettings = {
        :beanstalkHost  => mqHost,
        :beanstalkPort  => mqPort,
        :beanstalkQueue => @mqQueue
      }

      version              = '1.3.0'
      date                 = '2017-03-25'

      logger.info( '-----------------------------------------------------------------' )
      logger.info( ' CoreMedia - Graphite Client' )
      logger.info( "  Version #{version} (#{date})" )
      logger.info( '  Copyright 2016-2017 CoreMedia' )
      logger.info( '  used Services:' )
      logger.info( "    - graphite     : #{@graphiteURI}" )
      logger.info( "    - message Queue: #{mqHost}:#{mqPort}/#{@mqQueue}" )
      logger.info( '-----------------------------------------------------------------' )
      logger.info( '' )

      @mqConsumer  = MessageQueue::Consumer.new( @MQSettings )

      begin

        @apiInstance = RestClient::Resource.new(
          @graphiteURI,
          :timeout      => 10,
          :open_timeout => 10,
          :headers      => {},
          :verify_ssl   => false
        )
      rescue => e
        logger.error( e )

        raise( e )

      end

      return self

    end


  end

end


