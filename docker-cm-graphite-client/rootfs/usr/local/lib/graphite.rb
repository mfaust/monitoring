#!/usr/bin/ruby
#
#  28.08.2016 - bodsch
#
#
# v1.2.0
# -----------------------------------------------------------------------------

require 'net/http'
require 'uri'
require 'time'

require_relative 'logging'
require_relative 'message-queue'

# -------------------------------------------------------------------------------------------------------------------

module GraphiteAnnotions

  class Client

    include Logging

    def initialize( params = {} )

      graphiteHost      = params[:graphiteHost]     ? params[:graphiteHost]     : 'localhost'
      graphiteHttpPort  = params[:graphiteHttpPort] ? params[:graphiteHttpPort] : 8081
      graphitePort      = params[:graphitePort]     ? params[:graphitePort]     : 2003
      graphitePath      = params[:graphitePath]     ? params[:graphitePath]     : nil
      mqHost            = params[:mqHost]           ? params[:mqHost]           : 'localhost'
      mqPort            = params[:mqPort]           ? params[:mqPort]           : 11300
      @mqQueue          = params[:mqQueue]          ? params[:mqQueue]          : 'mq-graphite'

      @graphiteURI      = sprintf( 'http://%s:%s%s/events/', graphiteHost, graphiteHttpPort, graphitePath )
      @MQSettings = {
        :beanstalkHost => mqHost,
        :beanstalkPort => mqPort
      }

      version              = '1.2.0'
      date                 = '2017-01-13'

      logger.info( '-----------------------------------------------------------------' )
      logger.info( ' CoreMedia - Graphite Client' )
      logger.info( "  Version #{version} (#{date})" )
      logger.info( '  Copyright 2016-2017 Coremedia' )
      logger.info( '  used Services:' )
      logger.info( "    - Graphite     : #{@graphiteURI}" )
      logger.info( "    - Message Queue: #{mqHost}:#{mqPort}/#{@mqQueue}" )
      logger.info( '-----------------------------------------------------------------' )
      logger.info( '' )

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

        logger.debug( data )
        logger.debug( payload )

        logger.info( sprintf( 'add annotation \'%s\'for node %s', command, node ) )

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



    # annotations werden direct in die graphite geschrieben
    # POST
    # curl -v -H 'Accept: application/json' -X POST \
    #   http://localhost:8081/events/  \
    #   -d '{ "what": "annotions test", "tags": ["monitoring-16-01"], "data": "test another adding annotion for <b>WTF</b>" }'
    #
    # curl -v -H 'Accept: application/json' -X POST \
    #   http://monitoring-16-build/graphite/events/ \
    #   -d '{ "what": "annotions test", "tags": ["monitoring-16-01","loadtest"],  "data": "test another adding annotion for <b>WTF</b>" }'

    # GET
    # curl  'http://admin:admin@localhost/grafana/api/datasources/proxy/2/events/get_data?from=-12h&until=now&tags=monitoring-16-01%20created&intersection'

    def annotion( what, tags, data )

      str  = Time.now()

      # add 2h to fix a f*cking bug in django
      # with Version 1.9 we dont need this ... UASY
      # str = str + (60 * 60 * 2)
      _when = Time.parse(str.to_s).to_i

      uri = URI( @graphiteURI )

      data = {
        'what' => what,
        'when' => _when,
        'tags' => tags.flatten,
        'data' => data
      }

      logger.debug( JSON.pretty_generate( data ) )

      response = nil

      begin
        Net::HTTP.start( uri.host, uri.port ) do |http|
          request = Net::HTTP::Post.new( uri.request_uri )

#          request.set_form_data( data )
          request.add_field('Content-Type', 'application/json')
          request.body = JSON.generate( data )
#          request.basic_auth 'admin', 'admin'

          response     = http.request( request )
          responseCode = response.code.to_i

          # TODO
          # Errorhandling
          if( responseCode != 200 )
            # 200 – Created
            # 400 – Errors (invalid json, missing or invalid fields, etc)
            # 401 – Unauthorized
            # 404 –
            logger.error( sprintf( ' [%s] ', responseCode ) )
            logger.error( sprintf( '  %s  ', response.body ) )
          end
        end
      rescue Exception => e
        logger.error( e )
        logger.error( e.backtrace )

        status  = 404
        message = sprintf( 'internal error: %s', e )
      end

    end


    def nodeAnnotation( host, type )

      tag      = Array.new()
      message  = String.new()
      descr    = String.new()
      time     = Time.now().strftime( '%Y-%m-%d %H:%M:%S' )

      tag << host

      case type
      when 'create'
        tag << 'created'
        message = sprintf( 'Node <b>%s</b> created (%s)', host, time )
        descr   = 'node created'
      when 'destroy'
        tag << 'destroyed'
        message = sprintf( 'Node <b>%s</b> destroyed (%s)', host, time )
        descr   = 'node destroyed'
      end

      self.annotion( descr, tag, message )

    end


    def loadtestAnnotation( host, type )

      tag      = Array.new()
      message  = String.new()
      descr    = String.new()
      time     = Time.now().strftime( '%Y-%m-%d %H:%M:%S' )

      tag << host
      tag << 'loadtest'

      case type
      when 'start'

        message = sprintf( 'Loadtest for Node <b>%s</b> started (%s)', host, time )
        descr   = 'loadtest start'
      when 'stop'

        message = sprintf( 'Loadtest for Node <b>%s</b> ended (%s)', host, time )
        descr   = 'loadtest end'
      end

      self.annotion( descr, tag, message )

    end


    def deploymentAnnotation( host, descr, tags = [] )

      tag      = Array.new()
      time     = Time.now().strftime( '%Y-%m-%d %H:%M:%S' )

      tag << host
      tag << 'deployment'

      if( tags.count != 0 )
        tag << tags
        tag.flatten!
      end


      message = sprintf( 'Deployment on Node <b>%s</b> started (%s)', host, time )

      descr   = sprintf( 'Deployment %s', descr )

      self.annotion( descr, tag, message )

    end


    def generalAnnotation( host, descr, message, customTags = [] )

      tag      = Array.new()
      time     = Time.now().strftime( '%Y-%m-%d %H:%M:%S' )

      tag << host
      tag.push( customTags )

      message = sprintf( '%s <b>%s</b> (%s)', descr, host, time )

      descr   = host

      self.annotion( descr, tag, message )

    end


  end

end

