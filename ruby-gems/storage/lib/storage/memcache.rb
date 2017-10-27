#
#
#

require 'dalli'

# ---------------------------------------------------------------------------------------

module Storage

  class Memcached

    include Logging

    def initialize( params = {} )

      host      = params[:host]      ? params[:host]      : 'localhost'
      port      = params[:port]      ? params[:port]      : 11211
      namespace = params[:namespace] ? params[:namespace] : 'monitoring'
      expire    = params[:expire]    ? params[:expire]    : 10

      memcache_options = { :compress => true, :namespace => namespace.to_s }

      # :expires_in - default TTL in seconds (defaults to 0 or forever)
      memcache_options[:expires_in] = ( 60 * expire.to_i ) if( expire.to_i != 0 )
      memcache_host = format( '%s:%s', host, port )

      @mc = nil

      begin
        if( @mc.nil? )
          @mc = Dalli::Client.new( memcache_host , memcache_options )
          sleep( 3 )
        end
      rescue => e
        puts e
      end
    end


    def self.logger
      @@logger ||= Logger.new(STDOUT)
    end


    def self.logger=(logger)
      @@logger = logger
    end


    def self.cache_key( params = {} )

      params   = Hash[params.sort]
      Digest::MD5.hexdigest( params.to_s )
    end

    def get( key )

      result = {}
      result = @mc.get( key ) if( @mc )
      result
    end

    def set( key, value )

      @mc.set( key, value )
    end

    def self.delete( key )

      @mc.delete( key )
    end

  end

end

# ---------------------------------------------------------------------------------------

# EOF
