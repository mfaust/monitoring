
require_relative 'cache'

module JobQueue

  class Job

    def initialize( settings = {} )

      @jobs  = Cache::Store.new()
    end

    def cache_key(params = {} )

      params   = Hash[params.sort]
      Digest::MD5.hexdigest( params.to_s )
    end

    def add( params = {} )

      checksum = self.cache_key(params)

      if( self.jobs( params ) == false )
        @jobs.set( checksum ) { Cache::Data.new( 'true' ) }
      end

    end


    def del( params = {} )

      checksum = self.cache_key(params)

      @jobs.unset( checksum )
    end


    def jobs( params = {} )

      checksum = self.cache_key(params)
      current  = @jobs.get( checksum )

      result = false
      result = true if( current.nil? )

      result
    end

  end

end

