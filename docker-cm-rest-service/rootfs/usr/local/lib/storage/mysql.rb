

require 'mysql2'

module Storage


  class MySQL

    include Logging

    OFFLINE  = 0
    ONLINE   = 1
    DELETE   = 98
    PREPARE  = 99

    def initialize( params = {} )

      host            = params.dig(:mysql, :host)
      user            = params.dig(:mysql, :user)
      pass            = params.dig(:mysql, :password)
      @schema         = params.dig(:mysql, :schema)
      read_timeout    = params.dig(:mysql, :timeout, :read)    || 5
      write_timeout   = params.dig(:mysql, :timeout, :write)   || 5
      connect_timeout = params.dig(:mysql, :timeout, :connect) || 5

      logger.debug( params )

      @client     = nil

      begin

        until( @client != nil )

          @client = Mysql2::Client.new(
            :host            => host,
            :username        => user,
            :password        => pass,
            :database        => @schema,
            :read_timeout    => read_timeout,
            :write_timeout   => write_timeout,
            :connect_timeout => connect_timeout,
            :encoding        => 'utf8',
            :reconnect       => true
          )

          logger.info( 'create database connection' )
          sleep( 3 )
        end
      rescue Exception => e
        logger.error( "An error occurred for connection: #{e}" )

        raise( e )
      rescue => e
        logger.error( e )

        raise( e )
      end

      # SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME = 'DBName'
      @client.query('SET storage_engine=InnoDB')
      @client.query("CREATE DATABASE if not exists #{@schema}")

      self.prepare()

    end


    def prepare()

      @client.query( "USE #{@schema}" )

      @client.query(
        "CREATE TABLE IF NOT EXISTS dns (
          id         int(11) not null AUTO_INCREMENT,
          ip         varchar(16) not null default '',
          name       varchar(160) not null default '',
          fqdn       varchar(160) not null default '',
          status     enum('offline','online','delete','prepare','unknown') default 'unknown',
          creation   DATETIME DEFAULT   CURRENT_TIMESTAMP,
          changed    DATETIME ON UPDATE CURRENT_TIMESTAMP,
          PRIMARY KEY (`ID`),
          key(`ip`) )"
      )

      @client.query(
        "CREATE TABLE IF NOT EXISTS config (
          `key`      varchar(128),
          `value`    text not null,
          dns_ip     varchar(16),
          creation   DATETIME DEFAULT   CURRENT_TIMESTAMP,
          changed    DATETIME ON UPDATE CURRENT_TIMESTAMP,
          KEY(`key`),
          FOREIGN KEY (`dns_ip`)
          REFERENCES dns(`ip`)
          ON DELETE CASCADE
        )"
      )

      @client.query(
        "CREATE TABLE IF NOT EXISTS discovery (
          service    varchar(128) not null,
          port       int(4) not null,
          data       text not null,
          dns_ip     varchar(16),
          creation   DATETIME DEFAULT   CURRENT_TIMESTAMP,
          changed    DATETIME ON UPDATE CURRENT_TIMESTAMP,
          KEY(`service`),
          FOREIGN KEY (`dns_ip`)
          REFERENCES dns(`ip`)
          ON DELETE CASCADE
        )"
      )

    end

    def toJson( data )

      h = Hash.new()

      data.each do |k|

        # "Variable_name"=>"Innodb_buffer_pool_pages_free", "Value"=>"1"
        h[k['Variable_name']] =  k['Value']
      end

      return h

    end

    # -- dns ------------------------------------
    #
    def createDNS( params = {} )

      if( ! @client )
        return false
      end

      logger.debug( " createDNS( #{params} )")

      ip    = params.dig(:ip)
      name  = params.dig(:short)
      fqdn  = params.dig(:fqdn)

      statement = sprintf('SELECT count(ip) as count FROM dns WHERE ip = \'%s\' or name = \'%s\' or fqdn = \'%s\'', ip, name, fqdn )
      result    = @client.query( statement, :as => :hash )

      logger.debug( statement )
#      logger.debug( result.to_a )

      if( result.to_a.first.dig('count').to_i == 0 )

        statement = sprintf('insert into dns ( ip, name, fqdn, status ) values ( \'%s\', \'%s\', \'%s\', \'prepare\' )', ip, name, fqdn )
        result    = @client.query( statement, :as => :hash )

        logger.debug( statement )
        logger.debug( result.to_a )
      end
    end


    def removeDNS( params = {} )

      if( ! @client )
        return false
      end

      logger.debug( " removeDNS( #{params} )")
      ip    = params.dig(:ip)
      name  = params.dig(:short)
      fqdn  = params.dig(:fqdn)

      statement = sprintf('delete FROM dns WHERE ip = \'%s\' or name = \'%s\' or fqdn = \'%s\'', ip, name, fqdn )
      result    = @client.query( statement, :as => :hash )

      logger.debug( statement )
#      logger.debug( result.to_a )
    end


    def dnsData( params = {}  )

      if( ! @client )
        return false
      end

      logger.debug( " dnsData( #{params} )")

      ip    = params.dig(:ip)
      name  = params.dig(:short)
      fqdn  = params.dig(:fqdn)

      statement = sprintf('SELECT ip, name, fqdn FROM dns WHERE ip = \'%s\' or name = \'%s\' or fqdn = \'%s\'', ip, name, fqdn )
      result    = @client.query( statement, :as => :hash )

      logger.debug( statement )

      if( result.count != 0 )

        headers = result.fields # <= that's an array of field names, in order
        result.each(:as => :hash) do |row|
          return row
        end
      end

      return nil

    end
    #
    # -- dns ------------------------------------


    def nodes( params = {} )

      if( ! @client )
        return false
      end

      result = Array.new
      ip     = params.dig(:ip)
      name   = params.dig(:short)
      fqdn   = params.dig(:fqdn)
      status = params.dig(:status) # Database::ONLINE or [ Storage::MySQL::ONLINE, Storage::MySQL::PREPARE ]

      logger.debug( " nodes( #{params} )")

      w = Array.new

      if( ip != nil )
        w << sprintf( 'ip like \'%%%s%%\'', ip )
      end
      if( name != nil )
        w << sprintf( 'name like \'%%%s%%\'', name )
      end
      if( fqdn != nil )
        w << sprintf( 'fqdn like \'%%%s%%\'', fqdn )
      end

      if( status != nil )

        if( status.is_a?(Array) )

          status.each do |s|

            s = case s
              when Storage::MySQL::ONLINE
                'online'
              when  Storage::MySQL::OFFLINE
                'offline'
              when Storage::MySQL::DELETE
                'delete'
              when Storage::MySQL::PREPARE
                'prepare'
              else
                'unknown'
              end
            w << sprintf( 'status = \'%s\'', s )
          end
        else

          status = case status
            when Storage::MySQL::ONLINE
              'online'
            when  Storage::MySQL::OFFLINE
              'offline'
            when Storage::MySQL::DELETE
              'delete'
            when Storage::MySQL::PREPARE
              'prepare'
            else
              'unknown'
            end
          w << sprintf( 'status = \'%s\'', status )
        end

      end

      if( w.count != 0 )
        w = w.join( ' or ' )
        w = sprintf( 'where %s', w )
      else
        w = nil
      end

      statement = sprintf('SELECT ip, name, fqdn, status FROM dns %s', w  )

      logger.debug( statement )

      res    = @client.query( statement, :as => :hash )

      if( res.count != 0 )

        headers = res.fields # <= that's an array of field names, in order
        res.each(:as => :hash) do |row|

          result << row.dig('fqdn')
        end

        return result
      end

      return nil



      rec = @database[:v_status].select().where( w ) .to_a

      if( rec.count() != 0 )

        groupByHost = rec.group_by { |k| k[:shortname] }

        return groupByHost
      end

      return Hash.new()

    end


    def setStatus( params = {} )

      if( ! @client )
        return false
      end

      ip     = params.dig(:ip)
      name   = params.dig(:short)
      fqdn   = params.dig(:fqdn)
      status = params.dig(:status) # Database::ONLINE

      logger.debug( " setStatus( #{params} )")

      if( ip == nil )

        dns = self.dnsData( params )

        if( dns != nil )
          ip   = dns.dig('ip')
        else

          return false
        end
      end

      if( status != nil )

        status = case status
          when Storage::MySQL::ONLINE
            'online'
          when  Storage::MySQL::OFFLINE
            'offline'
          when Storage::MySQL::DELETE
            'delete'
          when Storage::MySQL::PREPARE
            'prepare'
          else
            'unknown'
          end

        statement = sprintf( 'update dns set status = \'%s\' where ip = \'%s\'', status, ip )

        result    = @client.query( statement, :as => :hash )

#         logger.debug( statement )
#         logger.debug( result.to_a )

        return true
      end

      return nil

    end


    def status( params = {} )

      if( ! @client )
        return false
      end

      ip    = params.dig(:ip)
      name  = params.dig(:short)
      fqdn  = params.dig(:fqdn)

      logger.debug( " status( #{params} )")

      statement = sprintf('SELECT ip, name, fqdn, status FROM dns WHERE ip = \'%s\' or name = \'%s\' or fqdn = \'%s\'', ip, name, fqdn )
      result    = @client.query( statement, :as => :hash )

      logger.debug( statement )

      if( result.count != 0 )

        headers = result.fields # <= that's an array of field names, in order
        result.each(:as => :hash) do |row|
          return row
        end
      end

      return nil
    end


    # -- configurations -------------------------
    #
    def createConfig( params = {} )

      if( ! @client )
        return false
      end

      ip     = params.dig(:ip)
      name   = params.dig(:short)
      fqdn   = params.dig(:fqdn)
      key    = params.dig(:key)
      values = params.dig(:value)
      data   = params.dig(:data)

      logger.debug( " createConfig( #{params} )")

      if( ( key == nil && values == nil ) && data.is_a?( Hash ) )

        data.each do |k,v|

          self.writeConfig( { :ip => ip, :short => name, :fqdn => fqdn, :key => k, :value => v } )
        end
      else

        self.writeConfig( params )
      end

      return nil

#       if( self.checkDatabase() == false )
#         return false
#       end
#
#       dnsIp        = params.dig(:ip)
#       dnsShortname = params.dig(:short)
#       dnsChecksum  = params.dig(:checksum)
#       configKey    = params.dig(:key)
#       configValues = params.dig(:value)
#       data         = params.dig(:data)
#
#       if( ( configKey == nil && configValues == nil ) && data.is_a?( Hash ) )
#
#         data.each do |k,v|
#
#           self.writeConfig( { :ip => dnsIp, :short => dnsShortname, :checksum => dnsChecksum, :key => k, :value => v } )
#         end
#       else
#
#         self.writeConfig( params )
#       end

    end

    # PRIVATE
    def writeConfig( params = {} )

      ip     = params.dig(:ip)
      name   = params.dig(:short)
      fqdn   = params.dig(:fqdn)
      key    = params.dig(:key)
      values = params.dig(:value)
      data   = params.dig(:data)

      logger.debug( " writeConfig( #{params} )")
      if( key == nil || values == nil )
        return false
      end

      if( ip == nil )

        dns = self.dnsData( params )

        if( dns != nil )
          ip   = dns.dig('ip')
        else

          return false
        end
      end


        statement = sprintf(
          'select * from config where `key` = \'%s\' and `value` = \'%s\' and dns_ip = \'%s\'',
          key, values, ip
        )

        logger.debug( statement )

        result    = @client.query( statement, :as => :hash )

#         logger.debug( result.class.to_s )
#         logger.debug( result.inspect )
#         logger.debug( result.size )

        if( result.size == 0 )

          statement = sprintf('insert into config ( `key`, `value`, dns_ip ) values ( \'%s\', \'%s\', \'%s\' )', key, values, ip )
          logger.debug( statement  )

          result    = @client.query( statement, :as => :hash )

          logger.debug( result.to_a )
        else

          dbaValues = nil

          result.each do |row|
            dbaValues    = row.dig('value')
          end

          logger.debug( "#{values} vs. #{dbaValues}" )

          if( dbaValues.to_s != values.to_s )

            statement = sprintf('update config set `value` = \'%s\' where dns_ip = \'%s\' and `key` = \'%s\'', values, ip, key )
            logger.debug( statement )

            result    = @client.query( statement, :as => :hash )

            logger.debug( result.to_a )
          end

        return nil




#         rec = @database[:config].where(
#           (
#             ( Sequel[:ip        => dnsIp.to_s] ) |
#             ( Sequel[:short => dnsShortname.to_s] )
#           ) & (
#             ( Sequel[:key   => configKey.to_s] ) &
#             ( Sequel[:value => configValues.to_s] )
#           )
#         ).to_a
#
#         if( rec.count() == 0 )
#
#           if( dnsIp != nil )
#             @database[:config].insert(
#               :ip       => dnsIp.to_s,
#               :key      => configKey.to_s,
#               :value    => configValues.to_s,
#               :created  => DateTime.now()
#             )
#
#           elsif( dnsShortname != nil )
#
#             @database[:config].insert(
#               :short => dnsShortname.to_s,
#               :key       => configKey.to_s,
#               :value     => configValues.to_s,
#               :created   => DateTime.now()
#             )
#           end
#         else
#
#           # prüfen, ob 'value' identisch ist
#           dbaValues    = rec.first[:value]
#           configValues = configValues.to_s
#
#           if( dbaValues != configValues )
#
#             if( dnsIp != nil )
#
#               @database[:config].where(
#                 ( Sequel[:ip  => dnsIp.to_s] ) &
#                 ( Sequel[:key => configKey.to_s] )
#               ).update(
#                 :value      => configValues.to_s,
#                 :created    => DateTime.now()
#               )
#             elsif( dnsShortname != nil )
#
#               @database[:config].where(
#                 ( Sequel[:short => dnsShortname.to_s] ) &
#                 ( Sequel[:key       => configKey.to_s] )
#               ).update(
#                 :value      => configValues.to_s,
#                 :created    => DateTime.now()
#               )
#             end
#           end
#         end
      end
    end


    def removeConfig( params = {} )

      if( ! @client )
        return false
      end

      ip    = params.dig(:ip)
      name  = params.dig(:short)
      fqdn  = params.dig(:fqdn)
      key   = params.dig(:key)

      logger.debug( " removeConfig( #{params} )")

      dns = self.dnsData( params )

      if( dns != nil )

        ip   = dns.dig('ip')
        more = nil

        logger.debug( ip )

        if( key != nil )
          more = sprintf( 'and `key` = \'%s\'', key )
        end

        statement = sprintf('DELETE FROM config WHERE dns_ip = \'%s\' %s', ip, more )
        logger.debug( statement )

        begin
          result    = @client.query( statement, :as => :hash )
          return true
        rescue => e
          logger.error( e)
          return false
        end

      end

      return nil
#
#       ip        = params[ :ip ]    ? params[ :ip ]    : nil
#       short     = params[ :short ] ? params[ :short ] : nil
#       long      = params[ :long ]  ? params[ :long ]  : nil
#       configKey = params[ :key ]   ? params[ :key ]   : nil
#
#       rec = @database[:config].select(:shortname).where(
#         ( Sequel[:ip        => ip.to_s] ) |
#         ( Sequel[:short => short.to_s] ) |
#         ( Sequel[:longname  => long.to_s] )
#       ).to_a
#
#       if( rec.count() != 0 )
#
#         shortname = rec.first[:shortname]
#
#         if( configKey == nil )
#
#           @database[:config].where( Sequel[:short => shortname] ).delete
#         else
#           @database[:config].where(
#             ( Sequel[:shortname   => shortname] ) &
#             ( Sequel[:key  => configKey] )
#           ).delete
#         end
#       end
    end
    def config( params = {} )

      if( ! @client )
        return false
      end

      ip     = params.dig(:ip)
      name   = params.dig(:short)
      fqdn   = params.dig(:fqdn)
      key    = params.dig(:key)

      logger.debug( " config( #{params} )")

      statement = sprintf(
        'select dns.fqdn, config.`key`, config.`value` from dns, config where dns.ip = config.dns_ip'
      )

      if( key != nil )
        statement = sprintf( '%s and `key` = \'%s\'', statement, key )
      end

      logger.debug( statement )

      r    = @client.query( statement, :as => :hash )

#       logger.debug( r.size )

      if( r.size == 0 )
        return nil
      end

      array   = Array.new
      result  = Hash.new()

      r.each do |row|

#         logger.debug( row )

        fqdn  = row.dig('fqdn')
        key   = row.dig('key')
        value = row.dig('value')

#         logger.debug(fqdn)

        result[fqdn.to_s] ||= {}
        result[fqdn.to_s][key.to_s] ||= self.parsedResponse( value )

      end

#       logger.debug( result )

      return result


  #       return nil
#
#
#
#       if( self.checkDatabase() == false )
#         return false
#       end
#
#       ip        = params[ :ip ]    ? params[ :ip ]    : nil
#       short     = params[ :short ] ? params[ :short ] : nil
#       long      = params[ :long ]  ? params[ :long ]  : nil
#       configKey = params[ :key ]   ? params[ :key ]   : nil
#
#       array     = Array.new()
#       result    = Hash.new()
#
#       def dbaData( w )
#
#         return  @database[:v_config].select( :ip, :shortname, :checksum, :key, :value ).where( w ).to_a
#
#       end
#
#       if( configKey == nil )
#
#         w = (
#           ( Sequel[:ip        => ip.to_s] ) |
#           ( Sequel[:short => short.to_s] ) |
#           ( Sequel[:longname  => long.to_s] )
#         )
#
#       else
#
#         w = (
#           ( Sequel[:ip        => ip.to_s] ) |
#           ( Sequel[:short => short.to_s] ) |
#           ( Sequel[:longname  => long.to_s] )
#         ) & (
#           ( Sequel[:key => configKey.to_s] )
#         )
#
#       end
#
#       def collectValues( hashes )
#
#         {}.tap{ |r| hashes.each{ |h| h.each{ |k,v| ( r[k]||=[] ) << v } } }
#       end
#
#       rec = self.dbaData( w )
#
#       if( rec.count() != 0 )
#
#         dnsShortName  = rec.first.dig( :checksum ).to_s
#
#         result[dnsShortName.to_s] ||= {}
#         result[dnsShortName.to_s]['dns'] ||= {}
#         result[dnsShortName.to_s]['dns']['ip']        = rec.first.dig( :ip ).to_s
#         result[dnsShortName.to_s]['dns']['shortname'] = rec.first.dig( :shortname ).to_s
#
#         groupByKey = rec.group_by { |k| k[:key] }
#
#         groupByKey.each do |g,v|
#
#           c = collectValues(
#             v.map do |hash|
#               { value:  ( hash[:value] ) }
#             end
#           )
#
#           values = c.select { |h| h['value'] }
#
#           result[dnsShortName.to_s][g.to_s] ||= {}
#           result[dnsShortName.to_s][g.to_s] = values[:value].flatten.sort
#
#           array << result
#         end
#       else
#         return false
#       end
#
#       array = array.reduce( :merge )
#
#       return array

    end
    #
    # -- configurations -------------------------

    # -- discovery ------------------------------
    #
    def createDiscovery( params = {}, append = false )

      if( ! @client )
        return false
      end

      ip      = params.dig(:ip)
      name    = params.dig(:short)
      fqdn    = params.dig(:fqdn)
      port    = params.dig(:port)
      service = params.dig(:service)
      data    = params.dig(:data)

      logger.debug( " createDiscovery( #{params}, #{append} )")
      if( ip == nil )

        dns = self.dnsData( { :ip => ip, :short => name, fqdn => fqdn } )

        if( dns != nil )
          ip   = dns.dig('ip')
          name = dns.dig('name')
          fqdn = dns.dig('fqdn')
        else

          return false
        end
      end

      if( service == nil && data.is_a?( Hash ) )

        data.each do |k,v|

          port = v.dig('port')

          self.writeDiscovery( { :ip => ip, :short => name, :fqdn => fqdn, :port => port, :service => k, :data => v } )
        end
      else

        params['ip']   = ip
        params['fqdn'] = fqdn

        self.writeDiscovery( params )
      end

      return nil

    end

    # PRIVATE
    def writeDiscovery( params = {} )

      ip      = params.dig(:ip)
      name    = params.dig(:short)
      fqdn    = params.dig(:fqdn)
      port    = params.dig(:port)
      service = params.dig(:service)
      data    = params.dig(:data)

      logger.debug( " writeDiscovery( #{params} )")

      statement = sprintf(
        'select port, service, dns_ip from discovery where `port` = \'%s\' and `service` = \'%s\' and dns_ip = \'%s\'',
        port, service, ip
      )

      logger.debug( statement )

      result    = @client.query( statement, :as => :hash )

      if( result.size == 0 )

        statement = sprintf('insert into discovery ( `port`, `service`, data, dns_ip ) values ( \'%s\', \'%s\', \'%s\', \'%s\' )', port, service, data.to_s, ip )
        logger.debug( statement  )

        result    = @client.query( statement, :as => :hash )

#         logger.debug( result.to_a )
      else

        dbaValues = nil

        result.each do |row|
          dbaValues    = row.dig('value')
        end

        logger.debug( "#{values} vs. #{dbaValues}" )

        if( dbaValues.to_s != values.to_s )

          statement = sprintf('update discovery set `data` = \'%s\' where dns_ip = \'%s\' and `port` = \'%s\' and `service` = \'%s\'', data.to_s, ip, port, service )
          logger.debug( statement )

          result    = @client.query( statement, :as => :hash )

#           logger.debug( result.to_a )
        end

      return nil

#
#       rec = discovery.where(
#         (Sequel[:dns_id   => dnsId.to_i] ) &
#         (Sequel[:service  => service.to_s] )
#       ).to_a
#
#       if( rec.count() == 0 )
#
#         return discovery.insert(
#
#           :dns_id     => dnsId.to_i,
#           :port       => port.to_i,
#           :service    => service,
#           :data       => data.to_s,
#           :created    => DateTime.now()
#         )
#
      end

    end





    def discoveryData( params = {} )

      if( ! @client )
        return false
      end

      ip        = params.dig(:ip)
      name      = params.dig(:short)
      fqdn      = params.dig(:fqdn)
      service   = params.dig(:service)
      result    = Hash.new()
      statement = nil

      logger.debug( " discoveryData( #{params} )")

      # constrains are the IP
      #
      if( ip == nil )

        dns = self.dnsData( params )

        if( dns != nil )
          ip   = dns.dig('ip')
          name = dns.dig('name')
        else

          return false
        end
      end


      # should be inpossible!
      #
      if( service == nil && name == nil )

        logger.error( '( service == nil && name == nil )' )
        return false
      end

      #  { :short => 'monitoring-16-01', :service => 'replication-live-server' }
      if( service != nil )

        statement = sprintf(
          'select name, fqdn, port, service, dns_ip, data from dns, discovery where ip = dns_ip and `service` = \'%s\' and dns_ip = \'%s\'',
          service, ip
        )
      elsif( service == nil )

        statement = sprintf(
          'select name, fqdn, port, service, dns_ip, data from dns, discovery where ip = dns_ip and dns_ip = \'%s\'',
          ip
        )

        r = Array.new()
        logger.debug( statement )
        res     = @client.query( statement, :as => :hash )

        if( res.count != 0 )

          headers = res.fields # <= that's an array of field names, in order
          res.each(:as => :hash) do |row|

            name     = row.dig('name').to_s
            fqdn     = row.dig('fqdn').to_s
            service  = row.dig('service').to_s
            dnsIp    = row.dig('dns_ip').to_i
            data     = row.dig('data')

            if( data == nil )
              next
            end

            data = data.gsub( '=>', ':' )
            data = self.parsedResponse( data )

            result[service.to_s] = data
          end

          if( result.is_a?( Array ) )
            result = Hash[*result]
          end

          return result
        end

        return nil

      end



      return nil

#       if( ip == nil )
#
#         dns = self.dnsData( params )
#
#         if( dns != nil )
#           ip   = dns.dig('ip')
#         else
#
#           return false
#         end
#       end
#
#       # TODO
#       # also WITHOUT 'service'
#       statement = sprintf(
#         'select * from discovery where `service` = \'%s\' and dns_ip = \'%s\'',
#         service, ip
#       )
#
# #      statement = sprintf('SELECT * FROM discovery WHERE ip = \'%s\' or name = \'%s\' or fqdn = \'%s\'', ip, name, fqdn )
#       result    = @client.query( statement, :as => :hash )
#
#       logger.debug( statement )
#
#       if( result.count != 0 )
#
#         headers = result.fields # <= that's an array of field names, in order
#         result.each(:as => :hash) do |row|
#           return row
#         end
#       end
#
#       return nil


    end
    #
    # -- discovery ------------------------------



    def parsedResponse( r )

      return JSON.parse( r )
    rescue JSON::ParserError => e
      return r # do smth

    end

    #
    # -- configurations -------------------------

  end


end
