
module Graphite

  module Annotions

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

      if( @timestamp.nil? )
        str  = Time.now

        # add 2h to fix a f*cking bug in django
        # with Version 1.9 we dont need this ... UASY
        # str = str + (60 * 60 * 2)
        _when = Time.parse(str.to_s).to_i
      else
        _when = @timestamp
      end

      uri = URI(@graphite_uri )

      data = {
        'what' => what,
        'when' => _when,
        'tags' => tags.flatten,
        'data' => data
      }

      endpoint = sprintf( '%s/events/', uri.request_uri )

      logger.debug( "data    : #{data}" )
      logger.debug( "endpoint: #{endpoint}" )

      begin
        response     = @api_instance[ '/events/' ].post( data.to_json, { 'Content-Type' => 'application/json' } )

        response_code    = response.code.to_i
        response_body    = response.body
        response_headers = response.headers

        if( ( response_code >= 200 && response_code <= 299 ) || ( response_code >= 400 && response_code <= 499 ) )

          { status: 200, message: 'annotation successful', annotation: data }
        else

          logger.error( "#{__method__}  on #{endpoint} failed: HTTP #{response_code} - #{response_body}" )
          JSON.parse( response_body )
        end

      rescue Errno::ECONNREFUSED

        logger.error( 'connection to graphite service refused' )

        { status: 500, message: 'connection to graphite service refused' }

      rescue RestClient::ExceptionWithResponse => e

        logger.error( "Error: #{__method__} #{method_type.upcase} on #{endpoint} error: '#{e}'" )
        logger.error( data )
        logger.error( "code  : #{response_code}" )
        logger.error( "body  : #{response_body}" )
        logger.error( JSON.pretty_generate( response_headers ) )
        logger.debug( e.inspect )

        return false

      rescue => e

        logger.error( "Error: #{__method__}  on #{endpoint} error: '#{e}'" )
        logger.error( data )
        logger.error( "code  : #{response_code}" )
        logger.error( "body  : #{response_body}" )
        logger.error( JSON.pretty_generate( response_headers ) )
        logger.debug( e.inspect )

        # logger.error(e)

        if( e.response )
          result           = JSON.parse( e.response )
        else
          result  = e.inspect
        end

        result['status'] = e.to_s.split( ' ' ).first

        return result
      end

    end


    def node_annotation(host, type )

      tag      = []
      message  = ''
      descr    = ''

      if( @timestamp.nil? )
        time     = Time.now.strftime( '%Y-%m-%d %H:%M:%S' )
      else
        time     = Time.at( @timestamp ).strftime( '%Y-%m-%d %H:%M:%S' )
      end

      tag << self.node_tag(host )

      if( type == 'create' )
        tag << 'created'
        message = sprintf( 'Node <b>%s</b> created (%s)', host, time )
        descr   = 'node created'
      elsif( type == 'remove' )
        tag << 'destroyed'
        message = sprintf( 'Node <b>%s</b> destroyed (%s)', host, time )
        descr   = 'node destroyed'
      else
        # type code here
      end

      annotion( descr, tag, message )

    end


    def loadtest_annotation(host, type )

      tag      = []
      message  = ''
      descr    = ''

      if( @timestamp.nil? )
        time     = Time.now.strftime( '%Y-%m-%d %H:%M:%S' )
      else
        time     = Time.at( @timestamp ).strftime( '%Y-%m-%d %H:%M:%S' )
      end

      tag << self.node_tag(host )
      tag << 'loadtest'

      if( type == 'start' )
        message = sprintf( 'Loadtest for Node <b>%s</b> started (%s)', host, time )
        descr   = 'loadtest start'
      elsif( type == 'stop' )
        message = sprintf( 'Loadtest for Node <b>%s</b> ended (%s)', host, time )
        descr   = 'loadtest end'
      else
        # type code here
      end

      annotion( descr, tag, message )
    end


    def deployment_annotation(host, descr, tags = [] )

      tag = []

      if( @timestamp.nil? )
        time     = Time.now.strftime('%Y-%m-%d %H:%M:%S' )
      else
        time     = Time.at( @timestamp ).strftime( '%Y-%m-%d %H:%M:%S' )
      end

#      tag << host
      tag << self.node_tag(host )
      tag << 'deployment'

      if( tags.count != 0 )
        tag << tags
        tag.flatten!
      end

      message = sprintf( 'Deployment on Node <b>%s</b> started (%s)', host, time )
      descr   = sprintf( 'Deployment %s', descr )

      annotion( descr, tag, message )
    end


    def general_annotation(host, descr, message, custom_tags = [] )

      tag = []

      if( @timestamp.nil? )
        time     = Time.now.strftime('%Y-%m-%d %H:%M:%S' )
      else
        time     = Time.at( @timestamp ).strftime( '%Y-%m-%d %H:%M:%S' )
      end

      tag << self.node_tag(host )
      tag.push(custom_tags )

      message = sprintf( '%s <b>%s</b> (%s)', descr, host, time )

      descr   = host

      annotion( descr, tag, message )
    end


  end

end

