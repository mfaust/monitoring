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

      # HINT or QUESTION
      # check payload if is an valid json?

      uri          = URI.parse( sprintf( 'http://%s:%s/jolokia', @Host, @Port ) )
      http         = Net::HTTP.new( uri.host, uri.port )

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

          return {
            :status  => 500,
            :message => e
          }

        rescue => e
          logger.warn( sprintf( 'Cannot execute request to %s://%s:%s%s, cause: %s', uri.scheme, uri.hostname, uri.port, uri.request_uri, e ) )

          return {
            :status  => 500,
            :message => e
          }

        end
      end

      return {
        :status  => 200,
        :message => JSON.parse( response.body )
      }

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

