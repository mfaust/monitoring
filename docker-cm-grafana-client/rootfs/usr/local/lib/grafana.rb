#!/usr/bin/ruby
#
# 13.01.2017 - Bodo Schulz
#
#
# v1.0.1

# -----------------------------------------------------------------------------

require 'uri'
require 'json'
require 'timeout'
require 'fileutils'
require 'time'
require 'date'
require 'time_difference'
require 'rest-client'

require_relative 'logging'
require_relative 'cache'
require_relative 'message-queue'
require_relative 'storage'
require_relative 'mbean'
require_relative 'grafana/queue'
require_relative 'grafana/http_request'
require_relative 'grafana/user'
require_relative 'grafana/users'
require_relative 'grafana/datasource'
require_relative 'grafana/organization'
require_relative 'grafana/organizations'
require_relative 'grafana/dashboard'
require_relative 'grafana/dashboard_template'
require_relative 'grafana/snapshot'
require_relative 'grafana/login'
require_relative 'grafana/admin'
require_relative 'grafana/version'
require_relative 'grafana/coremedia/tools'
require_relative 'grafana/coremedia/dashboard'

# -----------------------------------------------------------------------------

module Grafana

  class Client

    include Logging

    include Grafana::Queue
    include Grafana::HttpRequest
    include Grafana::User
    include Grafana::Users
    include Grafana::Datasource
    include Grafana::Organization
    include Grafana::Organizations
    include Grafana::Dashboard
    include Grafana::DashboardTemplate
    include Grafana::Snapshot
    include Grafana::Login
    include Grafana::Admin
    include Grafana::Coremedia::Tools
    include Grafana::Coremedia::Dashboard
    include Grafana::Coremedia::Templates
    include Grafana::Coremedia::Annotations
    include Grafana::Coremedia::Tags

    # Returns a new instance of Client
    #
    # @param [Hash, #read] params the configure the Client
    # @option params [String] :host the Grafana Hostname (default: 'localhost')
    # @option params [String] :port the Grafana Port (default: 80)
    # @option params [String] :user the Grafana User for Login (default: 'admin')
    # @option params [String] :password the Grafana Users Password for Login (default: '')
    # @option params [Bool] :debug enabled debug Output
    # @option params [Integer] :timeout Timeout for the RestClient
    # @option params [Integer] :open_timeout
    # @option params [String] :url_path advanced URL Path, when Grafana is located behind a Proxy Services, or the uri_path has changed
    # @option params [Bool] :ssl enable SSL Connections
    # @option params [Hash] :headers optional Header for an API Key Login
    # @example to create an new Instance
    #    config = {
    #      :host     => grafanaHost,
    #      :port     => grafanaPort,
    #      :user     => 'admin',
    #      :password => 'admin',
    #      :debug    => false,
    #      :timeout  => 3,
    #      :ssl      => false,
    #      :url_path => '/grafana'
    #    }
    #
    #    g = Grafana::Client.new( config )
    # @return [bool, #read]
    def initialize( settings = {} )

#      logger.debug( params )

      host                = settings.dig(:grafana, :host)          || 'localhost'
      port                = settings.dig(:grafana, :port)          || 80
      @user               = settings.dig(:grafana, :user)          || 'admin'
      @password           = settings.dig(:grafana, :password)      || ''
      urlPath             = settings.dig(:grafana, :url_path)      || ''
      ssl                 = settings.dig(:grafana, :ssl)           || false
      timeout             = settings.dig(:grafana, :timeout)       || 5
      open_timeout        = settings.dig(:grafana, :open_timeout)  || 5
      headers             = settings.dig(:grafana, :headers)       || {}

      @templateDirectory  = settings.dig(:templateDirectory)       || '/usr/local/share/templates/grafana'

      mqHost              = settings.dig(:mq, :host)               || 'localhost'
      mqPort              = settings.dig(:mq, :port)               || 11300
      @mqQueue            = settings.dig(:mq, :queue)              || 'mq-grafana'

      redisHost           = settings.dig(:redis, :host)
      redisPort           = settings.dig(:redis, :port)            || 6379

      mysqlHost           = settings.dig(:mysql, :host)
      mysqlSchema         = settings.dig(:mysql, :schema)
      mysqlUser           = settings.dig(:mysql, :user)
      mysqlPassword       = settings.dig(:mysql, :password)

      @MQSettings = {
        :beanstalkHost  => mqHost,
        :beanstalkPort  => mqPort,
        :beanstalkQueue => @mqQueue
      }

      if( timeout.to_i <= 0 )
        timeout = 5
      end

      if( open_timeout.to_i <= 0 )
        open_timeout = 5
      end

      proto        = ( ssl == true ? 'https' : 'http' )
      @url  = sprintf( '%s://%s:%s%s', proto, host, port, urlPath )

      @apiInstance = nil
      @loggedIn    = false
      @headers     = nil

      version            = '1.9.0'
      date               = '2017-06-03'

      logger.info( '-----------------------------------------------------------------' )
      logger.info( ' CoreMedia - Grafana Client' )
      logger.info( "  Version #{version} (#{date})" )
      logger.info( '  Copyright 2016-2017 Coremedia' )
      logger.info( '  used Services:' )
      logger.info( "    - grafana      : #{host}:#{port}#{urlPath}" )
      logger.info( "    - redis        : #{redisHost}:#{redisPort}" )
      if( mysqlHost != nil )
        logger.info( "    - mysql        : #{mysqlHost}@#{mysqlSchema}" )
      end
      logger.info( "    - message queue: #{mqHost}:#{mqPort}/#{@mqQueue}" )
      logger.info( '-----------------------------------------------------------------' )


      @redis       = Storage::RedisClient.new( { :redis => { :host => redisHost } } )
      @mbean       = MBean::Client.new( { :redis => @redis } )
      @cache       = Cache::Store.new()
      @mqConsumer  = MessageQueue::Consumer.new( @MQSettings )
      @mqProducer  = MessageQueue::Producer.new( @MQSettings )
      @database    = nil

      if( mysqlHost != nil )

        begin

          until( @database != nil )

            logger.debug( 'try to connect our database endpoint' )

            @database   = Storage::MySQL.new( {
              :mysql => {
                :host     => mysqlHost,
                :user     => mysqlUser,
                :password => mysqlPassword,
                :schema   => mysqlSchema
              }
            } )

            sleep(5)
          end
        rescue => e

          logger.error( e )
        end
      end

      @apiInstance = self.createApiInstance( {
        :timeout      => timeout,
        :open_timeout => open_timeout,
        :headers      => headers
      } )

      for y in 1..15

        @loggedIn = self.login( { :user => @user, :password => @password } )

        if( @loggedIn == true )
          logger.debug( 'login successful' )
          break
        else
          logger.debug( sprintf( 'Attempting to establish user session ... %d', y ) )
          sleep(5)
        end
      end

    end


    # create an REST-API Instance
    #
    def createApiInstance( params = {} )

      timeout      = params.dig(:timeout)
      open_timeout = params.dig(:open_timeout)
      headers      = params.dig(:headers)
      instance     = nil

      begin

        until( instance != nil )

          logger.debug( 'try to connect our grafana endpoint' )

          instance = RestClient::Resource.new(
            @url,
            :timeout      => timeout,
            :open_timeout => open_timeout,
            :headers      => headers,
            :verify_ssl   => false
          )

          sleep(5)
        end
      rescue => e

        logger.error( e )
      end

      return instance

    end



    # Login into Grafana
    #
    # @param [Hash, #read] params the params to create a valid login
    # @option params [String] :user The Username
    # @option params [String] :password The Password
    # @example For an successful Login
    #    login( { :user => 'admin', :password => 'admin' } )
    # @return [bool, #read]
    def login( params = {} )

      user     = params.dig(:user)      || @user
      password = params.dig(:password)  || @password
      headers  = params.dig(:headers)

      loggedIn = false

      if( headers != nil && headers.has_key?(:authorization) )

        # API key Auth
        @headers = {
          :content_type  => 'application/json; charset=UTF-8',
          :Authorization => headers.dig( :authorization )
        }

      else

        request_data = {
          'User'     => user,
          'Password' => password
        }

        begin

          resp = @apiInstance['/login'].post(
            request_data.to_json,
            { :content_type => 'application/json; charset=UTF-8' }
          )

          if( resp.code.to_i == 200 )

            @sessionCookies = resp.cookies

            @headers = {
              :content_type => 'application/json; charset=UTF-8',
              :cookies      => @sessionCookies
            }

            loggedIn = true
          else

            logger.error( "Error running POST request on /login: #{resp.code.to_i}" )
            logger.error( "#{resp}" )
            logger.error( "Request data: #{request_data.to_json}" )

            loggedIn = false
          end

        rescue => e

          logger.error( "Error running POST request on /login: #{e}" )
          logger.error( "Request data: #{request_data.to_json}" )

          loggedIn = false
        end

        return loggedIn

      end

    end

  end

end

# EOF

