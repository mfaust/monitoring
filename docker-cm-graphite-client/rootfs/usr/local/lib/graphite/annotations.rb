
module Graphite

  module Annotions

    def nodeTag( host )

#       logger.debug( "storagePath( #{host} )" )

      key    = sprintf( 'config-%s', host )
      data   = @cache.get( key )

      result = host

#       logger.debug( "cached data: #{data}" )

#      logger.debug( @redis.config( { :short => host } ) )

      if( data == nil )

        identifier = @redis.config( { :short => host, :key => 'graphite-identifier' } )

#         logger.debug( "identifier #1: #{identifier}" )

        if( identifier != nil )

          identifier = identifier.dig( 'graphite-identifier' )

#           logger.debug( "identifier #2: #{identifier}" )

          if( identifier != nil )
            result     = identifier
          end

          @cache.set( key, expiresIn: 320 ) { Cache::Data.new( result ) }
        end

      else

        result = data
      end

#       logger.debug( "result: #{result}" )

      return result

    end



    # annotations werden direct in die graphite geschrieben
    # POST
    # curl \
    #   --silent \
    #   --header 'Accept: application/json' \
    #   --request POST \
    #   http://localhost:8081/events/  \
    #   --data '{ "what": "annotions test", "tags": ["monitoring-16-01"], "data": "test another adding annotion for <b>WTF</b>" }'
    #
    # curl \
    #   --silent \
    #   --header 'Accept: application/json' \
    #   --request POST \
    #   http://monitoring-16-build/graphite/events/ \
    #   --data '{ "what": "annotions test", "tags": ["monitoring-16-01","loadtest"],  "data": "test another adding annotion for <b>WTF</b>" }'

    # GET
    # curl \
    #   --silent \
    #   "http://admin:admin@localhost/grafana/api/datasources/proxy/2/events/get_data?from=-12h&until=now&tags=monitoring-16-01%20created&intersection"

    def annotion( what, tags, data )

      if( @timestamp == nil )
        str  = Time.now()

        # add 2h to fix a f*cking bug in django
        # with Version 1.9 we dont need this ... UASY
        # str = str + (60 * 60 * 2)
        _when = Time.parse(str.to_s).to_i
      else
        _when = @timestamp
      end

      uri = URI( @graphiteURI )

      data = {
        'what' => what,
        'when' => _when,
        'tags' => tags.flatten,
        'data' => data
      }

      endpoint = sprintf( '%s/events/', uri.request_uri )

      begin

        response     = @apiInstance[ '/events/' ].post( data.to_json, { 'Content-Type' => 'application/json' } )

        responseCode = response.code.to_i
        responseBody = response.body

        if( ( responseCode >= 200 && responseCode <= 299 ) || ( responseCode >= 400 && responseCode <= 499 ) )

          result = {
            :status     => 200,
            :message    => 'annotation successful',
            :annotation => data
          }

          return result
        else

          logger.error( "#{__method__}  on #{endpoint} failed: HTTP #{response.code} - #{responseBody}" )

          return JSON.parse( responseBody )
        end

      rescue Errno::ECONNREFUSED

        logger.error( 'connection to graphite service refused' )

        return {
          :status   => 500,
          :message  => 'connection to graphite service refused'
        }

      rescue => e

        logger.error( "Error: #{__method__}  on #{endpoint} error: '#{e}'" )

        if( e.response )
          result           = JSON.parse( e.response )
        else
          result  = e.inspect
        end
          result['status'] = e.to_s.split( ' ' ).first

        return result
      end

    end


    def nodeAnnotation( host, type )

      tag      = Array.new()
      message  = String.new()
      descr    = String.new()

      if( @timestamp == nil )
        time     = Time.now().strftime( '%Y-%m-%d %H:%M:%S' )
      else
        time     = Time.at( @timestamp ).strftime( '%Y-%m-%d %H:%M:%S' )
      end

#      tag << host
      tag << self.nodeTag( host )

      case type
      when 'create'
        tag << 'created'
        message = sprintf( 'Node <b>%s</b> created (%s)', host, time )
        descr   = 'node created'
      when 'remove'
        tag << 'destroyed'
        message = sprintf( 'Node <b>%s</b> destroyed (%s)', host, time )
        descr   = 'node destroyed'
      end

      return self.annotion( descr, tag, message )

    end


    def loadtestAnnotation( host, type )

      tag      = Array.new()
      message  = String.new()
      descr    = String.new()

      if( @timestamp == nil )
        time     = Time.now().strftime( '%Y-%m-%d %H:%M:%S' )
      else
        time     = Time.at( @timestamp ).strftime( '%Y-%m-%d %H:%M:%S' )
      end

#      tag << host
      tag << self.nodeTag( host )
      tag << 'loadtest'

      case type
      when 'start'

        message = sprintf( 'Loadtest for Node <b>%s</b> started (%s)', host, time )
        descr   = 'loadtest start'
      when 'stop'

        message = sprintf( 'Loadtest for Node <b>%s</b> ended (%s)', host, time )
        descr   = 'loadtest end'
      end

      return self.annotion( descr, tag, message )

    end


    def deploymentAnnotation( host, descr, tags = [] )

      tag      = Array.new()

      if( @timestamp == nil )
        time     = Time.now().strftime( '%Y-%m-%d %H:%M:%S' )
      else
        time     = Time.at( @timestamp ).strftime( '%Y-%m-%d %H:%M:%S' )
      end

#      tag << host
      tag << self.nodeTag( host )
      tag << 'deployment'

      if( tags.count != 0 )
        tag << tags
        tag.flatten!
      end

      message = sprintf( 'Deployment on Node <b>%s</b> started (%s)', host, time )

      descr   = sprintf( 'Deployment %s', descr )

      return self.annotion( descr, tag, message )

    end


    def generalAnnotation( host, descr, message, customTags = [] )

      tag      = Array.new()

      if( @timestamp == nil )
        time     = Time.now().strftime( '%Y-%m-%d %H:%M:%S' )
      else
        time     = Time.at( @timestamp ).strftime( '%Y-%m-%d %H:%M:%S' )
      end

#      tag << host
      tag << self.nodeTag( host )
      tag.push( customTags )

      message = sprintf( '%s <b>%s</b> (%s)', descr, host, time )

      descr   = host

      return self.annotion( descr, tag, message )

    end


  end

end

