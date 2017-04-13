#!/usr/bin/ruby
#
# send graphite Annotations (or events) to our Graphite Service
#
#  28.08.2016 - bodsch
#
#
# v1.3.1
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

      graphiteHost      = params.dig(:graphite, :host)       || 'localhost'
      graphitePort      = params.dig(:graphite, :port)       || 2003
      graphiteHttpPort  = params.dig(:graphite, :http_port)  || 8081
      graphitePath      = params.dig(:graphite, :path)
      mqHost            = params.dig(:mq, :host)             || 'localhost'
      mqPort            = params.dig(:mq, :port)             || 11300
      @mqQueue          = params.dig(:mq, :queue)            || 'mq-graphite'

      @graphiteURI      = sprintf( 'http://%s:%s%s', graphiteHost, graphiteHttpPort, graphitePath )

      @MQSettings = {
        :beanstalkHost  => mqHost,
        :beanstalkPort  => mqPort,
        :beanstalkQueue => @mqQueue
      }

      version              = '1.3.1'
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


