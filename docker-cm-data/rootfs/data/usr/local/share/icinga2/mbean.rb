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

      logger.level = Logger::INFO
    end


    def bean( host, service, mbean )

      if( host.nil? || service.nil? || mbean.nil? )
        logger.error( "no valid data:" )
        logger.error( "  bean( #{host}, #{service}, #{mbean} )" )
        return false
      end

      data = Hash.new()

      logger.debug( { :host => host, :pre => 'result', :service => service } )
      cacheKey = Storage::RedisClient.cacheKey( { :host => host, :pre => 'result', :service => service } )

      begin
        result = @redis.get( cacheKey )
        if( result != nil )
          data = { service => result }
        end

      rescue => e

        logger.debug( 'retry ...')
        logger.error(e)
        sleep( 2 )
        retry
      end

#      for y in 1..10
#
#        result      = @redis.get( cache_key )
#
#        if( result != nil )
#          data = { service => result }
#          break
#        else
#          sleep( 3 )
#        end
#      end

      # ---------------------------------------------------------------------------------------

      begin

        logger.debug(data.keys)

        s   = data.dig(service)

        logger.debug(s)
        logger.debug(s.class.to_s)

        if( s.nil? )
          # no service found
          logger.debug("no service '#{service}' found")
          return false
        end

        if( s.count == 0 )
          logger.debug( "empty data for '#{service}'")
          return false
        end

        mbeanExists  = s.detect { |s| s[mbean] }

        if( mbeanExists == nil )
          # no mbean $mbean found
          logger.debug("no mbean '#{mbean}' for service '#{service}' found")
          return false
        end

        result = mbeanExists.dig(mbean)

      rescue JSON::ParserError => e

        logger.error('wrong result (no json)')
        logger.error(e)

        result = false
      end

      return result

    end


    def supportMbean?( data, service, mbean, key = nil )

      result = false

      if( data == nil )
        logger.error( 'no data given' )
        return false
      end

      s   = data.dig(service)

      if( s == nil )
        # no service found
        return false
      end

      mbeanExists  = s.detect { |s| s[mbean] }

      if( mbeanExists == nil )
        # no mbean $mbean found
        return false
      end

      mbeanExists  = mbeanExists.dig(mbean)
      mbeanStatus  = mbeanExists.dig('status') || 999

      if( mbeanStatus.to_i != 200 )
        # mbean $mbean found, but status != 200
        return false
      end

      if( mbeanExists != nil && key == nil )

        result = true
      elsif( mbeanExists != nil && key != nil )

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

      logger.debug( { :host => host, :pre => 'result', :service => service } )
      cacheKey = Storage::RedisClient.cacheKey( { :host => host, :pre => 'result', :service => service } )

      (1..15).each { |x|

        redis_data = @redis.get( cacheKey )

        if( redis_data.nil? )
          logger.debug(sprintf('wait for discovery data for node \'%s\' ... %d', host, x))
          sleep(3)
        else
          data = { service => redis_data }
          break
        end
      }

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

        difference = time_difference( t, n )
        difference = difference[:minutes].round(0)

        if( difference > quorum + 1 )

          logger.debug( sprintf( ' now       : %s', n.to_datetime.strftime("%d %m %Y %H:%M:%S") ) )
          logger.debug( sprintf( ' timestamp : %s', t.to_datetime.strftime("%d %m %Y %H:%M:%S") ) )
          logger.debug( sprintf( ' difference: %d', difference ) )

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

#          logger.error( sprintf( '  status: %d: %s (Host: \'%s\' :: Service: \'%s\' - mbean: \'%s\')', status, timestamp, host, service, mbean ) )
          logger.debug( sprintf( '  status: %d: %s (Host: \'%s\' :: mbean: \'%s\')', status, timestamp, host, mbean ) )
          return false
        end
      end

      return true

    end


    def time_difference( start_time, end_time )

      seconds_diff = (start_time - end_time).to_i.abs

      {
        years: (seconds_diff / 31556952),
        months: (seconds_diff / 2628288),
        weeks: (seconds_diff / 604800),
        days: (seconds_diff / 86400),
        hours: (seconds_diff / 3600),
        minutes: (seconds_diff / 60),
        seconds: seconds_diff,
      }
    end


  end

end
