
require_relative 'cache'

module JobQueue

  class Job

    include Logging

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

#       ip    = params.dig(:ip)
#       short = params.dig(:short)
#       fqdn  = params.dig(:fqdn)

      if( self.jobs( params ) == false )
        @jobs.set( checksum ) { Cache::Data.new( 'true' ) }
      end

    end


    def del( params = {} )

#       ip    = params.dig(:ip)
#       short = params.dig(:short)
#       fqdn  = params.dig(:fqdn)
      checksum = self.cacheKey(params)

      @jobs.unset( checksum )
    end


    def jobs( params = {} )

#       ip    = params.dig(:ip)
#       short = params.dig(:short)
#       fqdn  = params.dig(:fqdn)

      checksum = self.cacheKey(params)

      current = @jobs.get( checksum )

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

