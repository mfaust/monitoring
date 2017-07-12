#!/usr/bin/ruby
#
# 08.01.2017 - Bodo Schulz
#
#
# v1.1.0
# -----------------------------------------------------------------------------

require 'net/http'

require_relative 'logging'
require_relative 'utils/network'

module Jolokia

  class Client

    include Logging

    def initialize( params = {} )

#       logger.debug( JSON.pretty_generate( params ) )

      @Host     = params.dig(:host) || 'localhost'
      @Port     = params.dig(:port) || 8080
      @Path     = params.dig(:path) || '/jolokia'
      @authUser = params.dig(:auth, :user)
      @authPass = params.dig(:auth, :pass)

    end


    def post( params = {} )

#       logger.debug( 'Jolokia.post()' )
#       logger.debug( params )

      payload = params.dig(:payload) || {}
      timeout = params.dig(:timeout) || 10

      # HINT or QUESTION
      # check payload if is an valid json?

      uri          = URI.parse( sprintf( 'http://%s:%s%s', @Host, @Port, @Path ) )
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

        max_retries   = 5
        times_retried = 0

        begin

          http.request( request )

        rescue Net::ReadTimeout => e

          if( times_retried < max_retries )

            times_retried += 1
            logger.warn( sprintf( 'Cannot execute request to %s://%s:%s%s, cause: %s', uri.scheme, uri.hostname, uri.port, uri.request_uri, e ) )
            logger.warn( "   retry #{times_retried}/#{max_retries}" )
            logger.debug( sprintf( ' -> request body: %s', request.body ) )

            sleep( 5 )
            retry
          else
            logger.error( 'Exiting request ...' )
            error = sprintf( '%s for request %s://%s:%s%s, cause: %s, request: %s', error, uri.scheme, uri.hostname, uri.port, uri.request_uri, e, request.body )
            logger.error( error )

            return {
              :status  => 500,
              :message => error
            }
          end

#        rescue Timeout::Error, Errno::EINVAL, Errno::ECONNRESET, EOFError, Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError, Net::ProtocolError => e
        rescue Errno::EINVAL, Errno::ECONNRESET, EOFError, Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError, Net::ProtocolError => e

          error = sprintf( '%s for request %s://%s:%s%s, cause: %s, request: %s', error, uri.scheme, uri.hostname, uri.port, uri.request_uri, e, request.body )

          logger.error( error )

          return {
            :status  => 500,
            :message => error
          }
        end

#         rescue Exception => e
#
#           logger.warn( sprintf( 'Cannot execute request to %s://%s:%s%s, cause: %s', uri.scheme, uri.hostname, uri.port, uri.request_uri, e ) )
#           logger.debug( sprintf( ' -> request body: %s', request.body ) )
#
#           return {
#             :status  => 500,
#             :message => e
#           }
#
# #         rescue => e
# #
# #           logger.warn( sprintf( 'Cannot execute request to %s://%s:%s%s, cause: %s', uri.scheme, uri.hostname, uri.port, uri.request_uri, e ) )
# #           logger.debug( sprintf( ' -> request body: %s', request.body ) )
# #
# #           return {
# #             :status  => 500,
# #             :message => e
# #           }
#
#         end
      end

      body = JSON.parse( response.body )

#       logger.debug( 'done' )
#       logger.debug( body.first )

      requestStatus = body.first['status'] ? body.first['status'] : 500
      requestError  = body.first['error']  ? body.first['error']  : nil

#       logger.debug( requestStatus )
#       logger.debug( requestError )

      if( requestStatus != 200 )

        # stacktrace found! :(
        return {
          :status   => requestStatus,
          :message  => requestError
        }
      end

      return {
        :status  => 200,
        :message => body
      }

    end


    def jolokiaIsAvailable?( params = {} )

      host = params.dig(:host) ||  @Host
      port = params.dig(:port) ||  @Port

      # if our jolokia proxy available?
      if( ! Utils::Network.portOpen?( host, port ) )
        logger.error( 'jolokia service is not available!' )
        return false
      end

      return true
    end

  end

end

