#!/usr/bin/ruby
#
# send graphite Annotations (or events) to our Graphite Service
#
#  bodsch
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

      graphite_host        = settings.dig(:graphite, :host)       || 'localhost'
      graphite_port        = settings.dig(:graphite, :port)       || 2003
      graphite_http_port   = settings.dig(:graphite, :http_port)  || 8081
      graphite_path        = settings.dig(:graphite, :path)
      mq_host              = settings.dig(:mq, :host)             || 'beanstalkd'
      mq_port              = settings.dig(:mq, :port)             || 11300
      @mq_queue            = settings.dig(:mq, :queue)            || 'mq-graphite'

      @graphite_uri        = format('http://%s:%s%s', graphite_host, graphite_http_port, graphite_path )

      mq_settings = {
        :beanstalkHost  => mq_host,
        :beanstalkPort  => mq_port,
        :beanstalkQueue => @mq_queue
      }

      version              = '1.5.0'
      date                 = '2017-10-26'

      logger.info( '-----------------------------------------------------------------' )
      logger.info( ' CoreMedia - Graphite Client' )
      logger.info( "  Version #{version} (#{date})" )
      logger.info( '  Copyright 2016-2017 CoreMedia' )
      logger.info( '  used Services:' )
      logger.info( "    - graphite     : #{@graphite_uri}" )
      logger.info( "    - message Queue: #{mq_host}:#{mq_port}/#{@mq_queue}" )
      logger.info( '-----------------------------------------------------------------' )
      logger.info( '' )

      @mq_consumer  = MessageQueue::Consumer.new(mq_settings )
      @mq_producer  = MessageQueue::Producer.new(mq_settings )

      begin

        @api_instance = RestClient::Resource.new(
            @graphite_uri,
            :timeout      => 10,
            :open_timeout => 10,
            :headers      => {},
            :verify_ssl   => false
        )
      rescue => e
        logger.error( e )

        raise( e )
      end

      self
    end
  end
end
