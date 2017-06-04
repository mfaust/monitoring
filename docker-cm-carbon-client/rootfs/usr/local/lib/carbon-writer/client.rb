
require_relative 'logging'
require_relative '../carbon-data'

module CarbonWriter

  class Client

    include Logging

    def initialize( settings = {} )

      redisHost     = settings.dig(:redis, :host)   || 'localhost'
      redisPort     = settings.dig(:redis, :port)   || 6379

      mysqlHost     = settings.dig(:mysql, :host)
      mysqlSchema   = settings.dig(:mysql, :schema)
      mysqlUser     = settings.dig(:mysql, :user)
      mysqlPassword = settings.dig(:mysql, :password)

      @graphiteHost = settings.dig( :graphite, :host )
      @graphitePort = settings.dig( :graphite, :port )

      version             = '1.4.0'
      date                = '2017-06-04'

      logger.info( '-----------------------------------------------------------------' )
      logger.info( ' CoreMedia - Carbon client' )
      logger.info( "  Version #{version} (#{date})" )
      logger.info( '  Copyright 2017 Coremedia' )
      logger.info( '  used Services:' )
      logger.info( "    - carbon       : #{@graphiteHost}:#{@graphitePort}" )
      logger.info( '-----------------------------------------------------------------' )
      logger.info( '' )

      @carbonData   = CarbonData::Consumer.new( { :redis => { :host => redisHost, :port => redisPort }, :mysql => { :host => mysqlHost, :schema => mysqlSchema, :user => mysqlUser, :password  => mysqlPassword } } )

    end


    def socket()

      if( ! @socket || @socket.closed? )

        begin

          @socket = TCPSocket.new( @graphiteHost, @graphitePort )

        rescue => e

          logger.error( e )

        retry
          sleep( 5 )
        end
      end

      return @socket

    end


    def run()

      start = Time.now
      nodes = @carbonData.nodes()

      if( nodes == nil || nodes.is_a?( FalseClass ) )
        logger.info( 'no online server found' )
      else

        nodes.each do |n|

          data = @carbonData.run( n )

          if( data.is_a?( Array ) )
            data.flatten!
          end

          finish = Time.now

          logger.info( sprintf( 'getting %s measurepoints in %s seconds', data.count, finish - start ) )

          data.each do |m|
            self.metric( m )
          end

        end

      end

    end


    def metric( metric = {} )

      if( metric == nil )
        return
      end

      key   = metric.dig(:key)
      value = metric.dig(:value)
      time  = metric.dig(:time) || Time.now

      # TODO
      # value must be an float!

      if( key == nil || value == nil )

        if( key == nil )
          logger.error( 'missing \'key\' entry' )
          logger.debug( sprintf( 'metric( %s )', metric ) )
        end

        if( value == nil )
          logger.error( 'missing \'value\' entry' )
          logger.debug( sprintf( 'metric( %s )', metric ) )
        end

        return
      end

      begin

#        logger.debug( " = carbon-writer.#{key} #{value.to_f} #{time.to_i}" )

        self.socket.write( "carbon-writer.#{key} #{value.to_f} #{time.to_i}\n" )

      rescue Errno::EPIPE, Errno::EHOSTUNREACH, Errno::ECONNREFUSED

        @socket = nil
        nil

      end
    end


    def closeSocket()

      if( @socket )
        @socket.close
      end

      @socket = nil
    end

  end

end
