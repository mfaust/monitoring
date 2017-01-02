#!/usr/bin/ruby
#
#  28.08.2016 - bodsch
#
#
# v1.1.1
# -----------------------------------------------------------------------------

# require 'logger'
require 'net/http'
require 'uri'
require 'time'

require_relative 'logging'

# -------------------------------------------------------------------------------------------------------------------

module GraphiteAnnotions

  class Client

    include Logging

    def initialize( settings = {} )

      @logDirectory     = settings[:logDirectory]     ? settings[:logDirectory]     : '/tmp'
      @graphiteHost     = settings[:graphiteHost]     ? settings[:graphiteHost]     : 'localhost'
      @graphiteHttpPort = settings[:graphiteHttpPort] ? settings[:graphiteHttpPort] : 8081
      @graphitePort     = settings[:graphitePort]     ? settings[:graphitePort]     : 2003
      @graphitePath     = settings[:graphitePath]     ? settings[:graphitePath]     : nil

      @graphiteURI      = sprintf( 'http://%s:%s%s/events/', @graphiteHost, @graphiteHttpPort, @graphitePath )
# 
#       logFile        = sprintf( '%s/graphite.log', @logDirectory )
#       file           = File.open( logFile, File::WRONLY | File::APPEND | File::CREAT )
#       file.sync      = true
#       @log           = Logger.new( file, 'weekly', 1024000 )
# #      @log = Logger.new( STDOUT )
#       logger.level     = Logger::DEBUG
#       logger.datetime_format = "%Y-%m-%d %H:%M:%S::%3N"
#       logger.formatter = proc do |severity, datetime, progname, msg|
#         "[#{datetime.strftime(logger.datetime_format)}] #{severity.ljust(5)} : #{msg}\n"
#       end

      version              = '1.1.2'
      date                 = '2016-11-28'

      logger.info( '-----------------------------------------------------------------' )
      logger.info( ' CoreMedia - Graphite Client' )
      logger.info( "  Version #{version} (#{date})" )
      logger.info( '  Copyright 2016 Coremedia' )
      logger.info( "  Backendsystem #{@graphiteURI}" )
      logger.info( '-----------------------------------------------------------------' )
      logger.info( '' )

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
            # 412 – Precondition failed
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

    # OBSOLETE
    def nodeCreatedAnnotation( host )

      tag  = sprintf( '%s created', host )
      data = sprintf( 'Node <b>%s</b> created (%s)', host, Time.now().strftime( '%Y-%m-%d %H:%M:%S' ) )

      self.annotion( 'node created', tag, data )

    end

    # OBSOLETE
    def nodeDestroyedAnnotation( host )

      tag  = sprintf( '%s destroyed', host )
      data = sprintf( 'Node <b>%s</b> destroyed (%s)', host, Time.now().strftime( '%Y-%m-%d %H:%M:%S' ))

      self.annotion( 'node destroyed', tag, data )

    end

    # OBSOLETE
    def loadTestStartAnnotation( host )

      tag  = sprintf( '%s loadtest', host )
      data = sprintf( 'Load Test for Node <b>%s</b> started (%s)', host, Time.now().strftime( '%Y-%m-%d %H:%M:%S' ) )

      self.annotion( 'load test start', tag, data )

    end

    # OBSOLETE
    def loadTestStopAnnotation( host )

      tag  = sprintf( '%s loadtest', host )
      data = sprintf( 'Load Test for Node <b>%s</b> ended (%s)', host, Time.now().strftime( '%Y-%m-%d %H:%M:%S' ) )

      self.annotion( 'load test end', tag, data )

    end

    # OBSOLETE
    def startAnnotation( host, data )

      tag = sprintf( '%s start', host )

      self.annotion( 'starting', host, data )

    end

    # OBSOLETE
    def stopAnnotation( host, data )

      tag = sprintf( '%s stop', host )

      self.annotion( 'stopping', host, data )

    end


  end

end

