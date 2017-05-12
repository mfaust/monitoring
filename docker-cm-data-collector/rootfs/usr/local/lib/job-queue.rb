
require_relative 'cache'

module JobQueue

  class Job

    include Logging

    def initialize( settings = {} )

      @jobs  = Cache::Store.new()
    end

    def add( params = {} )

      ip    = params.dig(:ip)
      short = params.dig(:short)
      fqdn  = params.dig(:fqdn)

      if( self.jobs( params ) == false )
        @jobs.set( fqdn ) { Cache::Data.new( 'true' ) }
      end

    end


    def del( params = {} )

      ip    = params.dig(:ip)
      short = params.dig(:short)
      fqdn  = params.dig(:fqdn)

      @jobs.unset( fqdn )
    end


    def jobs( params = {} )

      ip    = params.dig(:ip)
      short = params.dig(:short)
      fqdn  = params.dig(:fqdn)

      current = @jobs.get( fqdn )

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

