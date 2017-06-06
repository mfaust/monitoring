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
require_relative 'graphite/tools'
require_relative 'graphite/annotations'
require_relative 'graphite/queue'

# -------------------------------------------------------------------------------------------------------------------

module Graphite

  class Client

    include Logging

    include Graphite::Tools
    include Graphite::Annotions
    include Graphite::Queue

    def initialize( settings = {} )

      graphiteHost        = settings.dig(:graphite, :host)       || 'localhost'
      graphitePort        = settings.dig(:graphite, :port)       || 2003
      graphiteHttpPort    = settings.dig(:graphite, :http_port)  || 8081
      graphitePath        = settings.dig(:graphite, :path)
      mqHost              = settings.dig(:mq, :host)             || 'localhost'
      mqPort              = settings.dig(:mq, :port)             || 11300
      @mqQueue            = settings.dig(:mq, :queue)            || 'mq-graphite'

      @graphiteURI        = sprintf( 'http://%s:%s%s', graphiteHost, graphiteHttpPort, graphitePath )

      @MQSettings = {
        :beanstalkHost  => mqHost,
        :beanstalkPort  => mqPort,
        :beanstalkQueue => @mqQueue
      }

      version              = '1.4.2'
      date                 = '2017-06-04'

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
      @mqProducer  = MessageQueue::Producer.new( @MQSettings )

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


