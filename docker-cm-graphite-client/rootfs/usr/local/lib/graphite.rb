#!/usr/bin/ruby
#
#  28.08.2016 - bodsch
#
#
# v1.2.0
# -----------------------------------------------------------------------------

require 'rest-client'
require 'uri'
require 'time'

require_relative 'logging'
require_relative 'message-queue'
require_relative 'graphite/annotations'

# -------------------------------------------------------------------------------------------------------------------

module Graphite

  class Client

    include Logging

    include Graphite::Annotions

    def initialize( params = {} )

      graphiteHost      = params[:graphiteHost]     ? params[:graphiteHost]     : 'localhost'
      graphiteHttpPort  = params[:graphiteHttpPort] ? params[:graphiteHttpPort] : 8081
      graphitePort      = params[:graphitePort]     ? params[:graphitePort]     : 2003
      graphitePath      = params[:graphitePath]     ? params[:graphitePath]     : nil
      mqHost            = params[:mqHost]           ? params[:mqHost]           : 'localhost'
      mqPort            = params[:mqPort]           ? params[:mqPort]           : 11300
      @mqQueue          = params[:mqQueue]          ? params[:mqQueue]          : 'mq-graphite'
      debug             = params[:debug]            ? params[:debug]            : false

      @graphiteURI      = sprintf( 'http://%s:%s%s', graphiteHost, graphiteHttpPort, graphitePath )
      @MQSettings = {
        :beanstalkHost => mqHost,
        :beanstalkPort => mqPort
      }

      logger.debug( params )

      if( debug == true )
        logger.level = Logger::DEBUG
      end

      version              = '1.2.0'
      date                 = '2017-01-13'

      logger.info( '-----------------------------------------------------------------' )
      logger.info( ' CoreMedia - Graphite Client' )
      logger.info( "  Version #{version} (#{date})" )
      logger.info( '  Copyright 2016-2017 Coremedia' )
      logger.info( '  used Services:' )
      logger.info( "    - graphite     : #{@graphiteURI}" )
      logger.info( "    - message Queue: #{mqHost}:#{mqPort}/#{@mqQueue}" )
      logger.info( '-----------------------------------------------------------------' )
      logger.info( '' )

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

        return nil
      end

      return self

    end

    # Message-Queue Integration
    #
    #
    #
    def queue()

      c = MessageQueue::Consumer.new( @MQSettings )

      threads = Array.new()

      threads << Thread.new {

        self.processQueue(
          c.getJobFromTube( @mqQueue )
        )
      }

      threads.each { |t| t.join }

    end


        # { :cmd => 'create'    , :node => host, :queue => 'mq-graphite', :payload => { "node": node } }
        # { :cmd => 'remove'    , :node => host, :queue => 'mq-graphite', :payload => { "node": node } }
        # { :cmd => 'loadtest'  , :node => host, :queue => 'mq-graphite', :payload => { "argument": argument } }
        # { :cmd => 'deployment', :node => host, :queue => 'mq-graphite', :payload => { "message": => message, "tags" => tags } }
        # { :cmd => 'general'   , :node => host, :queue => 'mq-graphite', :payload => { "message": => message, "tags" => tags, "description" => description } }


    def processQueue( data = {} )

      if( data.count != 0 )

        logger.info( sprintf( 'process Message from Queue %s: %d', data.dig(:tube), data.dig(:id) ) )

        @timestamp = nil

        command    = data.dig( :body, 'cmd' )     || nil
        node       = data.dig( :body, 'node' )    || nil
        payload    = data.dig( :body, 'payload' ) || nil
        timestamp  = payload.dig( 'timestamp' )
#         logger.debug( timestamp )

        if( timestamp != nil )

          if( timestamp.is_a?( Time ) )

#             logger.debug( 'is Time' )
            timestamp = Time.parse( timestamp )

            logger.debug( @timestamp )
          end

          @timestamp = timestamp.to_i

#           logger.debug( @timestamp )
        end

        if( command == nil )
          logger.error( 'no command' )
          logger.error( data )

          return {
            :status  => 400,
            :message => 'no command',
            :request => data
          }
        end

        if( node == nil || payload == nil )
          logger.error( 'missing node or payload' )
          logger.error( data )

          return {
            :status  => 400,
            :message => 'missing node or payload',
            :request => data
          }
        end

        result = {
          :status  => 400,
          :message => sprintf( 'wrong command detected: %s', command )
        }

        logger.info( sprintf( 'add annotation \'%s\' for node %s', command, node ) )

        case command
        when 'create', 'remove'

          result = self.nodeAnnotation( node, command )

          logger.info( result )
        when 'loadtest'

          argument = payload.dig( 'argument' )

          if( argument != 'start' || argument != 'stop' )
            logger.error( sprintf( 'wrong argument for LOADTEST \'%s\'', argument ) )
            return
          end

          result = self.loadtestAnnotation( node, argument )

          logger.info( result )

        when 'deployment'

          message = payload.dig( 'message' )
          tags    = payload.dig( 'tags' ) || []

          result = self.deploymentAnnotation( node, message, tags )

          logger.info( result )
        when 'general'

          description = payload.dig( 'description' )
          message     = payload.dig( 'message' )
          tags        = payload.dig( 'tags' ) || []

          result = self.generalAnnotation( node, description, message, tags )

          logger.info( result )
        else
          logger.error( sprintf( 'wrong command detected: %s', command ) )

          result = {
            :status  => 400,
            :message => sprintf( 'wrong command detected: %s', command )
          }

          logger.info( result )
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
      from: 'discovery',
      payload: data
    }.to_json

    logger.debug( p.addJob( 'mq-information', job ) )

  end

  end

end


