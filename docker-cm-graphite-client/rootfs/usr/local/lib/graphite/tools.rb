
module Graphite

  module Tools

    def nodeTag( host )

#       logger.debug( "storagePath( #{host} )" )

      key    = sprintf( 'config-%s', host )
      data   = @cache.get( key )

      result = host

#       logger.debug( "cached data: #{data}" )

#      logger.debug( @redis.config( { :short => host } ) )

      if( data == nil )

        identifier = @redis.config( { :short => host, :key => 'graphite-identifier' } )

#         logger.debug( "identifier #1: #{identifier}" )

        if( identifier != nil )

          identifier = identifier.dig( 'graphite-identifier' )

#           logger.debug( "identifier #2: #{identifier}" )

          if( identifier != nil )
            result     = identifier
          end

          @cache.set( key, expiresIn: 320 ) { Cache::Data.new( result ) }
        end

      else

        result = data
      end

#       logger.debug( "result: #{result}" )

      return result

    end

  end

end

