#!/usr/bin/ruby
#
#  28.08.2016 - bodsch
#
#
# v1.1.0
# -----------------------------------------------------------------------------

require 'logger'
require 'net/http'
require 'uri'
require 'time'

# -------------------------------------------------------------------------------------------------------------------

module GraphiteAnnotions

  class Client

    def initialize( settings = {} )

      @logDirectory     = settings['logDirectory']     ? settings['logDirectory']     : '/tmp'

      @graphiteHost     = settings['graphiteHost']     ? settings['graphiteHost']     : 'localhost'
      @graphiteHttpPort = settings['graphiteHttpPort'] ? settings['graphiteHttpPort'] : 8081
      @graphitePort     = settings['graphitePort']     ? settings['graphitePort']     : 2003
      @graphitePath     = settings['graphitePath']     ? settings['graphitePath']     : nil

      @graphiteURI      = sprintf( 'http://%s:%s%s', @graphiteHost, @graphiteHttpPort, @graphitePath )

      logFile = sprintf( '%s/graphite.log', @logDirectory )

      file      = File.open( logFile, File::WRONLY | File::APPEND | File::CREAT )
      file.sync = true
      @log = Logger.new( file, 'weekly', 1024000 )
#      @log = Logger.new( STDOUT )
      @log.level = Logger::DEBUG
      @log.datetime_format = "%Y-%m-%d %H:%M:%S::%3N"
      @log.formatter = proc do |severity, datetime, progname, msg|
        "[#{datetime.strftime(@log.datetime_format)}] #{severity.ljust(5)} : #{msg}\n"
      end

      version              = '0.1.0'
      date                 = '2016-09-29'

      @log.info( '-----------------------------------------------------------------' )
      @log.info( ' CoreMedia - Graphite' )
      @log.info( "  Version #{version} (#{date})" )
      @log.info( '  Copyright 2016 Coremedia' )
      @log.info( "  Backendsystem #{ @graphiteURI}" )
      @log.info( '-----------------------------------------------------------------' )
      @log.info( '' )

    end

    def annotion( what, tags, data )

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

      str  = Time.now()

      # add 2h to fix a f*cking bug in django
      str = str + (60 * 60 * 2)

      @log.debug( str.to_s )
      _when = Time.parse(str.to_s).to_i

#       uri    = sprintf( 'http://%s:%s/events/', @graphiteHost, @graphiteHttpPort )

      uri = URI( @graphiteURI )

      data = {
        'what' => what,
        'when' => _when,
        'tags' => tags,
        'data' => data
      }

#       @log.debug( uri )
      @log.debug( data )

      response = nil
      Net::HTTP.start( uri.host, uri.port ) do |http|
        request = Net::HTTP::Post.new( uri.request_uri )

#        request.set_form_data( data )
        request.add_field('Content-Type', 'application/json')
        request.body = JSON.generate( data )
#        request.basic_auth 'admin', 'admin'

        response     = http.request( request )

        @log.debug( "response: #{response.code}" )
      end

    end


    def nodeAnnotation( host, type )

      tag      = Array.new()
      message  = String.new()
      descr    = String.new()
      time     = Time.now().strftime( '%Y-%m-%d %H:%M:%S' )

      tag[] << host

      case type
      when 'create'
        tag[] << 'created'
        message = sprintf( 'Node <b>%s</b> created (%s)', host, time )
        descr   = 'node created'
      when 'destroy'
        tag[] << 'destroyed'
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

      tag[] << host
      tag[] << 'loadtest'

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


    def deploymentAnnotation( host, message )

      tag      = Array.new()
      message  = String.new()
      descr    = String.new()
      time     = Time.now().strftime( '%Y-%m-%d %H:%M:%S' )

      tag[] << host
      tag[] << 'deployment'

      message = sprintf( 'Deployment on Node <b>%s</b> started (%s)', host, time )

      descr   = 'Deployment start'

      self.annotion( descr, tag, message )

    end


    def generalAnnotation( host, descr, message, customTags = [] )

      tag      = Array.new()
      message  = String.new()
      time     = Time.now().strftime( '%Y-%m-%d %H:%M:%S' )

      tag[] << host
      tag.push( customTags )

      message = sprintf( '%s <b>%s</b> (%s)', descr, host, time )

      descr   = host

      self.annotion( descr, tag, message )

    end

    def nodeCreatedAnnotation( host )

      tag  = sprintf( '%s created', host )
      data = sprintf( 'Node <b>%s</b> created (%s)', host, Time.now().strftime( '%Y-%m-%d %H:%M:%S' ) )

      self.annotion( 'node created', tag, data )

    end

    def nodeDestroyedAnnotation( host )

      tag  = sprintf( '%s destroyed', host )
      data = sprintf( 'Node <b>%s</b> destroyed (%s)', host, Time.now().strftime( '%Y-%m-%d %H:%M:%S' ))

      self.annotion( 'node destroyed', tag, data )

    end

    def loadTestStartAnnotation( host )

      tag  = sprintf( '%s loadtest', host )
      data = sprintf( 'Load Test for Node <b>%s</b> started (%s)', host, Time.now().strftime( '%Y-%m-%d %H:%M:%S' ) )

      self.annotion( 'load test start', tag, data )

    end

    def loadTestStopAnnotation( host )

      tag  = sprintf( '%s loadtest', host )
      data = sprintf( 'Load Test for Node <b>%s</b> ended (%s)', host, Time.now().strftime( '%Y-%m-%d %H:%M:%S' ) )

      self.annotion( 'load test end', tag, data )

    end


    def startAnnotation( host, data )

      tag = sprintf( '%s start', host )

      self.annotion( 'starting', host, data )

    end

    def stopAnnotation( host, data )

      tag = sprintf( '%s stop', host )

      self.annotion( 'stopping', host, data )

    end


  end

end

