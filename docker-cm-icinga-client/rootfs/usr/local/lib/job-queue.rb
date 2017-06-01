
require_relative 'cache'

module JobQueue

  class Job

    def initialize( settings = {} )

      @jobs  = Cache::Store.new()
    end

    def cacheKey( params = {} )

      params   = Hash[params.sort]
      checksum = Digest::MD5.hexdigest( params.to_s )

      return checksum

    end

    def add( params = {} )

      checksum = self.cacheKey(params)

      if( self.jobs( params ) == false )
        @jobs.set( checksum ) { Cache::Data.new( 'true' ) }
      end

    end


    def del( params = {} )

      checksum = self.cacheKey(params)

      @jobs.unset( checksum )
    end


    def jobs( params = {} )

      checksum = self.cacheKey(params)
      current  = @jobs.get( checksum )

      if( current == nil )
        # no entry found
        return false
      else
        # entry exists
        return true
      end

    end

  end

end

