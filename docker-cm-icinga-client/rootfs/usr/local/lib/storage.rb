#!/usr/bin/ruby

require 'rubygems'
require 'json'
require 'dalli'
require 'sequel'
require 'digest/md5'

require_relative 'logging'
require_relative 'tools'

# -----------------------------------------------------------------------------

module Storage

  class Memcached

    include Logging

    def initialize( params = {} )

      host      = params[:host]      ? params[:host]      : 'localhost'
      port      = params[:port]      ? params[:port]      : 11211
      namespace = params[:namespace] ? params[:namespace] : 'monitoring'
      expire    = params[:expire]    ? params[:expire]    : 10

      memcacheOptions = {
        :compress   => true,
        :namespace  => namespace.to_s
      }

      if( expire.to_i != 0 )
        memcacheOptions[:expires_in] = ( 60 * expire.to_i )  # :expires_in - default TTL in seconds (defaults to 0 or forever)
      end

      @mc = nil

      begin
        until( @mc != nil )
#           logger.debug( 'try ...' )
          @mc = Dalli::Client.new( sprintf( '%s:%s', host, port ), memcacheOptions )
          sleep( 3 )
        end
      rescue => e
        logger.error( e )
      end
    end

    def self.cacheKey( params = {} )

      params   = Hash[params.sort]
      checksum = Digest::MD5.hexdigest( params.to_s )

      return checksum

    end

    def get( key )

      result = {}

      if( @mc )
#         logger.debug( @mc.stats( :items ) )
#         sleep(4)
        result = @mc.get( key )
      end

      return result
    end

    def set( key, value )

      return @mc.set( key, value )
    end

  end


end

# ---------------------------------------------------------------------------------------

# EOF
