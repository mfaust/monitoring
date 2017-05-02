#
#
#

require_relative 'monkey'
require_relative 'storage'

module MBean

  class Client

    include Logging

    def initialize( params = {} )

      redis = params.dig(:redis)

      if( redis != nil )
        @redis = redis
      end

      logger.level = Logger::DEBUG
    end



    def bean( host, service, mbean )

      data = Hash.new()

      cacheKey = Storage::RedisClient.cacheKey( { :host => host, :pre => 'result', :service => service } )

      for y in 1..3

        result      = @redis.get( cacheKey )

        if( result != nil )
          data = { service => result }
          break
        else
  #        logger.debug( sprintf( 'Waiting for data %s ... %d', cacheKey, y ) )
          sleep( 3 )
        end
      end

      # ---------------------------------------------------------------------------------------

      begin

        s   = data.dig(service)

        if( s == nil )
  #        logger.debug( sprintf( 'no service %s found', service ) )
          return false
        end

        mbeanExists  = s.detect { |s| s[mbean] }

        if( mbeanExists == nil )
  #        logger.debug( sprintf( 'no mbean %s found', mbean ) )
          return false
        end

        mbeanExists  = mbeanExists.dig(mbean)
        mbeanStatus  = mbeanExists.dig('status') || 999

        return mbeanExists

        if( mbeanStatus.to_i != 200 )
  #        logger.debug( sprintf( 'mbean %s found, but status %d', mbean, mbeanStatus ) )
          return false
        end

        if( mbeanExists != nil && key == nil )

          result = true
        elsif( mbeanExists != nil && key != nil )

  #        logger.debug( sprintf( 'look for key %s', key ) )

          mbeanValue = mbeanExists.dig('value')

          if( mbeanValue == nil )
            return false
          end

          if( mbeanValue.is_a?( Hash ) )
            mbeanValue = mbeanValue.values.first
          end

          attribute = mbeanValue.dig(key)

          if( attribute == nil || ( attribute.is_a?(String) && attribute.include?( 'ERROR' ) ) )

            return false
          end
        end

      rescue JSON::ParserError => e

        logger.error('wrong result (no json)')
        logger.error(e)

        result = false
      end

      return result

    end


    def supportMbean?( data, service, mbean, key = nil )

      result = false

      logger.debug( sprintf( 'supportMbean?( %s, %s, mbean, %s )', data, service, key ) )

      if( data == nil )
        logger.error( 'no data given' )
        return false
      end

      s   = data.dig(service)

      if( s == nil )
        logger.debug( sprintf( 'no service %s found', service ) )
        return false
      end

      mbeanExists  = s.detect { |s| s[mbean] }

      if( mbeanExists == nil )
        logger.debug( sprintf( 'no mbean %s found', mbean ) )
        return false
      end

      mbeanExists  = mbeanExists.dig(mbean)
      mbeanStatus  = mbeanExists.dig('status') || 999

      if( mbeanStatus.to_i != 200 )

        logger.debug( sprintf( 'mbean %s found, but status %d', mbean, mbeanStatus ) )
        return false
      end

      if( mbeanExists != nil && key == nil )

        result = true
      elsif( mbeanExists != nil && key != nil )

        logger.debug( sprintf( 'look for key %s', key ) )

        mbeanValue = mbeanExists.dig('value')

        if( mbeanValue == nil )
          return false
        end

        if( mbeanValue.is_a?(Hash) )
          mbeanValue = mbeanValue.values.first
        end

        attribute = mbeanValue.dig(key)

        if( attribute == nil || ( attribute.is_a?(String) && attribute.include?( 'ERROR' ) ) )

          return false
        end
        return true
      end

      return result
    end


    def beanAvailable?( host, service, bean, key = nil )

      data     = nil
      cacheKey = Storage::RedisClient.cacheKey( { :host => host, :pre => 'result', :service => service } )

      for y in 1..10

        result = @redis.get( cacheKey )

        if( result != nil )
          data = { service => result }
          break
        else
          logger.debug( sprintf( 'Waiting for data %s ... %d', cacheKey, y ) )
          sleep( 3 )
        end
      end

      # ---------------------------------------------------------------------------------------

      if( data == nil )
        logger.error( 'no data found' )
        return false
      end

      begin
        result = self.supportMbean?( data, service, bean, key )
      rescue JSON::ParserError => e

        logger.error('wrong result (no json)')
        logger.error(e)

        result = false
      end

      return result
    end


    def beanName( mbean )

      regex = /
        ^                     # Starting at the front of the string
        (.*)                  #
        name=                 #
        (?<name>.+[a-zA-Z])   #
        (.*),                 #
        type=                 #
        (?<type>.+[a-zA-Z])   #
        $
      /x

      parts           = mbean.match( regex )
      mbeanName       = parts['name'].to_s
      mbeanType       = parts['type'].to_s

      return mbeanName

    end


    def beanTimeout?( timestamp )

      result = false
      quorum = 1 # in minutes

      if( timestamp == nil || timestamp.to_s == 'null' )
        result = true
      else
        n = Time.now()
        t = Time.at( timestamp )
        t = t.addMinutes( quorum ) + 10

        difference = TimeDifference.between( t, n ).in_each_component
        difference = difference[:minutes].ceil

        if( difference > quorum + 1 )

  #         logger.debug( sprintf( ' now       : %s', n.to_datetime.strftime("%d %m %Y %H:%M:%S") ) )
  #         logger.debug( sprintf( ' timestamp : %s', t.to_datetime.strftime("%d %m %Y %H:%M:%S") ) )
  #         logger.debug( sprintf( ' difference: %d', difference ) )

          result = true
        end
      end

      return result

    end


    def checkBeanConsistency( mbean, data = {} )

    status    = data.dig('status')    # ? data['status']    : 505
    timestamp = data.dig('timestamp') # ? data['timestamp'] : 0
    host      = data.dig('host')
    service   = data.dig('service')
    value     = data.dig('value')

    result = {
      :mbean     => mbean,
      :status    => status,
      :timestamp => timestamp
    }

    if( status.to_i == 200 )
      return true
    else
      if( self.beanTimeout?( timestamp ) )

        logger.error( sprintf( '  status: %d: %s (Host: \'%s\' :: Service: \'%s\' - mbean: \'%s\')', status, timestamp, host, service, mbean ) )
        logger.debug( data )
        return false
      end
    end

    return true

  end

  end

end
