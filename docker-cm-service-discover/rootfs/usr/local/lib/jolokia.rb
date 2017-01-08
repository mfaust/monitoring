#!/usr/bin/ruby
#
# 08.01.2017 - Bodo Schulz
#
#
# v0.0.9
# -----------------------------------------------------------------------------

require 'net/http'

require_relative 'logging'

module Jolokia

  class Client

    include Logging

    def initialize( params = {} )

      @Host = params[:host] ? params[:host] : 'localhost'
      @Port = params[:port] ? params[:port] : 8080

    end

    def post( params = {} )

      payload = params[:payload] ? params[:payload] : {}
      timeout = params[:timeout] ? params[:timeout] : 10

      uri          = URI.parse( sprintf( 'http://%s:%s', @Host, @Port ) )
      http         = Net::HTTP.new( uri.host, uri.port )

#       request      = Net::HTTP::Post.new( '/jolokia/' )
#       request.add_field('Content-Type', 'application/json')
#
#       body = JSON.pretty_generate( array )
#
#       logger.debug( body )
#
#       request.body = body
#
#       begin
#
#         response     = http.request( request )
#
#       rescue Timeout::Error, Errno::ECONNREFUSED, Errno::EINVAL, Errno::ECONNRESET, EOFError, Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError, Net::ProtocolError => error
#
#         logger.error( error )
#
#         case error
#         when Errno::ECONNREFUSED
#           logger.error( 'connection refused' )
#         when Errno::ECONNRESET
#           logger.error( 'connection reset' )
#         end
#       end

      # ---------------------------------------------------------------------

      request = Net::HTTP::Post.new(
        uri.request_uri,
        initheader = { 'Content-Type' =>'application/json' }
      )
      request.body = payload.to_json

      # default read timeout is 60 secs
      response = Net::HTTP.start(
        uri.hostname,
        uri.port,
        use_ssl: uri.scheme == "https",
        :read_timeout => timeout
      ) do |http|
        begin
          http.request( request )
        rescue Exception => e
          logger.warn( sprintf( 'Cannot execute request to %s://%s:%s%s, cause: %s', uri.scheme, uri.hostname, uri.port, uri.request_uri, e ) )

#           logger.debug( sprintf( ' -> request body: %s', request.body ) )
          return
        rescue => e
          logger.warn( sprintf( 'Cannot execute request to %s://%s:%s%s, cause: %s', uri.scheme, uri.hostname, uri.port, uri.request_uri, e ) )

        end
      end

      result = response.body

      return result

    end

    def jolokiaIsAvailable?( params = {} )

      host = params[:host] ? params[:host] : @Host
      port = params[:port] ? params[:port] : @Port


      # if our jolokia proxy available?
      if( ! self.portOpen?( host, port ) )
        logger.error( 'jolokia service is not available!' )
        return false
      end

      return true
    end

    def portOpen? ( host, port, seconds = 1 )

      # => checks if a port is open or not on a remote host
      Timeout::timeout( seconds ) do
        begin
          TCPSocket.new( host, port ).close
          return true
        rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH, SocketError => e
          logger.error( e )
          return false
        end
      end
      rescue Timeout::Error => e
        logger.error( e )
        return false
    end
  end

end

