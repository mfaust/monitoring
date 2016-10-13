#
#
#

require_relative 'tools'


class MBean

  def self.logger( logger )
    @log = logger
  end

  def self.memcache( host, port )
    @memcacheHost = host
    @memcachePort = port

    require 'dalli'

    if( !@mc )

      memcacheOptions = {
        :compress   => true,
        :namespace  => 'monitoring',
        :expires_in => 0
      }

      @mc = Dalli::Client.new( sprintf( '%s:%s', @memcacheHost, @memcachePort ), memcacheOptions )

    end
  end

  def self.cacheDirectory( dir )
    @cacheDirectory = dir
  end


  def self.bean( host, service, mbean, useMemcache = true )

    data = Hash.new()

    if( useMemcache == true )

      require 'dalli'

      if( !@mc )

        memcacheOptions = {
          :compress   => true,
          :namespace  => 'monitoring',
          :expires_in => 0
        }

        @mc = Dalli::Client.new( sprintf( '%s:%s', @memcacheHost, @memcachePort ), memcacheOptions )

      end

      memcacheKey = cacheKey( 'result', host, service )
#       @log.debug( sprintf( 'cachekey : %s', memcacheKey ) )

#      memcacheKey         = sprintf( 'result__%s__%s', host, service )

      for y in 1..3

        result      = @mc.get( memcacheKey )

        if( result != nil )
          data = { service => result }
          break
        else
#           @log.debug( sprintf( 'Waiting for data %s ... %d', memcacheKey, y ) )
          sleep( 3 )
        end
      end
    else

      fileName = sprintf( "%s/%s/monitoring.result", @cacheDirectory, host )

      for y in 1..10

        if( File.exist?( fileName ) )
          sleep( 1 )
          file = File.read( fileName )
          break
        end

#         @log.debug( sprintf( 'Waiting for file %s ... %d', fileName, y ) )
        sleep( 3 )
      end

      if( file )
        data   = JSON.parse( file )
      end
    end

    # ---------------------------------------------------------------------------------------

    begin

      s   = data[service] ? data[service] : nil

      if( s == nil )
#         @log.debug( sprintf( 'no service %s found', service ) )
        return false
      end

      mbeanExists  = s.detect { |s| s[mbean] }

      if( mbeanExists == nil )
#         @log.debug( sprintf( 'no mbean %s found', mbean ) )
        return false
      end

      mbeanExists  = mbeanExists[mbean]    ? mbeanExists[mbean]    : nil
      mbeanStatus  = mbeanExists['status'] ? mbeanExists['status'] : 999

      return mbeanExists

      if( mbeanStatus.to_i != 200 )

#         @log.debug( sprintf( 'mbean %s found, but status %d', mbean, mbeanStatus ) )
        return false
      end

      if( mbeanExists != nil && key == nil )

        result = true
      elsif( mbeanExists != nil && key != nil )

#         @log.debug( sprintf( 'look for key %s', key ) )

        mbeanValue = mbeanExists['value'] ? mbeanExists['value'] : nil

        if( mbeanValue == nil )
          return false
        end

        if( mbeanValue.class.to_s == 'Hash' )
          mbeanValue = mbeanValue.values.first
        end

        attribute = mbeanValue[ key ] ? mbeanValue[ key ]  : nil

        if( attribute == nil || ( attribute.is_a?(String) && attribute.include?( 'ERROR' ) ) )

          return false
        end
      end

    rescue JSON::ParserError => e

      @log.error('wrong result (no json)')
      @log.error(e)

      result = false
    end

    return result

  end


  def self.supportMbean?( data, service, mbean, key = nil )

    result = false

    s   = data[service] ? data[service] : nil

    if( s == nil )
      @log.debug( sprintf( 'no service %s found', service ) )
      return false
    end

    mbeanExists  = s.detect { |s| s[mbean] }

    if( mbeanExists == nil )
      @log.debug( sprintf( 'no mbean %s found', mbean ) )
      return false
    end

    mbeanExists  = mbeanExists[mbean]    ? mbeanExists[mbean]    : nil
    mbeanStatus  = mbeanExists['status'] ? mbeanExists['status'] : 999

    if( mbeanStatus.to_i != 200 )

      @log.debug( sprintf( 'mbean %s found, but status %d', mbean, mbeanStatus ) )
      return false
    end

    if( mbeanExists != nil && key == nil )

      result = true
    elsif( mbeanExists != nil && key != nil )

      @log.debug( sprintf( 'look for key %s', key ) )

      mbeanValue = mbeanExists['value'] ? mbeanExists['value'] : nil

      if( mbeanValue == nil )
        return false
      end

      if( mbeanValue.class.to_s == 'Hash' )
        mbeanValue = mbeanValue.values.first
      end

      attribute = mbeanValue[ key ] ? mbeanValue[ key ]  : nil

      if( attribute == nil || ( attribute.is_a?(String) && attribute.include?( 'ERROR' ) ) )

        return false
      end
      return true
    end

    return result
  end


  def self.beanAvailable?( host, service, bean, key = nil )

    fileName = sprintf( "%s/%s/monitoring.result", @cacheDirectory, host )

    for y in 1..10

      if( File.exist?( fileName ) )
        sleep( 1 )
        file = File.read( fileName )
        break
      end

      @log.debug( sprintf( 'Waiting for file %s ... %d', fileName, y ) )
      sleep( 3 )
    end

    if( file )

      begin
        json   = JSON.parse( file )
        result = self.supportMbean?( json, service, bean, key )
      rescue JSON::ParserError => e

        @log.error('wrong result (no json)')
        @log.error(e)

        result = false
      end
    end

    return result
  end


  def self.beanName( mbean )

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


  def self.beanTimeout?( timestamp )

    result = false
    quorum = 1 # in minutes

    if( timestamp == nil || timestamp.to_s == 'null' )
      result = true
    else
      n = Time.now()
      t = Time.at( timestamp )
      t = t.add_minutes( quorum ) + 10

      difference = TimeDifference.between( t, n ).in_each_component
      difference = difference[:minutes].ceil

      if( difference > quorum + 1 )

        @log.debug( sprintf( ' now       : %s', n.to_datetime.strftime("%d %m %Y %H:%M:%S") ) )
        @log.debug( sprintf( ' timestamp : %s', t.to_datetime.strftime("%d %m %Y %H:%M:%S") ) )
        @log.debug( sprintf( ' difference: %d', difference ) )

        result = true
      end
    end

    return result

  end


  def self.checkBean‎Consistency( mbean, data = {} )

    result = true

    status    = data['status']    ? data['status']    : 505
    timestamp = data['timestamp'] ? data['timestamp'] : 0

    if( self.beanTimeout?( timestamp ) )

      @log.error( sprintf( ' -> Host: \'%s\' - Service: \'%s\' - mbean: \'%s\' - status: \'timeout\'', @Host, @Service, mbean ) )
      result = false
    end

    if( status.to_i != 200 )

      @log.error( sprintf( ' -> Host: \'%s\' - Service: \'%s\' - mbean: \'%s\' - status: \'%d\'', @Host, @Service, mbean, status ) )
      result = false
    end

    return result

  end



end
