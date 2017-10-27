#
#
#

require 'mysql2'

# ---------------------------------------------------------------------------------------

module Storage

  class MySQL

#    include Logging

    OFFLINE  = 0
    ONLINE   = 1
    DELETE   = 98
    PREPARE  = 99

    def initialize( params )

      @host            = params.dig(:mysql, :host)
      @user            = params.dig(:mysql, :user)
      @pass            = params.dig(:mysql, :password)
      @schema          = params.dig(:mysql, :schema)
      @read_timeout    = params.dig(:mysql, :timeout, :read)    || 15
      @write_timeout   = params.dig(:mysql, :timeout, :write)   || 15
      @connect_timeout = params.dig(:mysql, :timeout, :connect) || 25

#       logger.level = Logger::INFO

      @client          = connect

      # SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME = 'DBName'
      @client.query('SET storage_engine=InnoDB')
      @client.query("CREATE DATABASE if not exists #{@schema}")

      self.prepare
    end


    def self.logger
      @@logger ||= Logger.new(STDOUT)
    end


    def self.logger=(logger)
      @@logger = logger
    end


    def connect

      begin

        retries ||= 0

        client = Mysql2::Client.new(
          :host            => @host,
          :username        => @user,
          :password        => @pass,
          :database        => @schema,
          :read_timeout    => @read_timeout,
          :write_timeout   => @write_timeout,
          :connect_timeout => @connect_timeout,
          :encoding        => 'utf8',
          :reconnect       => true
        )

      rescue

#         logger.debug(format('try to create the database connection (%d)', retries))
#         logger.error(e)

        if( retries < 20 )
          retries += 1
          sleep( 5 )
          retry
        end
      end

#       logger.info( 'database connection established' )
      client
    end


    def prepare

      @client.query( "USE #{@schema}" )

      @client.query(
        "CREATE TABLE IF NOT EXISTS dns (
          id         int(11) not null AUTO_INCREMENT,
          ip         varchar(16)  not null,
          name       varchar(160) not null,
          fqdn       varchar(255) not null,
          status     enum('offline','online','delete','prepare','unknown') default 'unknown',
          creation   DATETIME DEFAULT   CURRENT_TIMESTAMP,
          PRIMARY KEY (`ID`),
          key(`ip`),
          unique( ip, name, fqdn, status )
        )"
      )

      @client.query('CREATE TABLE IF NOT EXISTS config (
          `key`      varchar(128) not null,
          `value`    varchar(255) not null,
          dns_ip     varchar(16),
          creation   DATETIME DEFAULT   CURRENT_TIMESTAMP,
          KEY(`key`),
          unique( `key`, `value`, dns_ip ),
          FOREIGN KEY (`dns_ip`) REFERENCES dns(`ip`)
          ON DELETE CASCADE
        )'
      )

      @client.query('CREATE TABLE IF NOT EXISTS discovery (
          service    varchar(128) not null,
          port       int(4)       not null,
          data       text         not null,
          dns_ip     varchar(16),
          creation   DATETIME DEFAULT   CURRENT_TIMESTAMP,
          KEY(`service`,`port`),
          unique( service, port, dns_ip ),
          FOREIGN KEY (`dns_ip`) REFERENCES dns(`ip`)
          ON DELETE CASCADE
        )'
      )

#       @client.query(
#         "create table if not exists measurements (
#           measurements         text not null,
#           discovery_service    varchar(128),
#           discovery_port       int(4),
#           dns_ip               varchar(16),
#           unique( discovery_service, discovery_port, dns_ip ),
#           FOREIGN KEY (`dns_ip`)         REFERENCES dns(`ip`),
#           FOREIGN KEY (`discovery_service`) REFERENCES discovery(`service`)
#           ON DELETE CASCADE
#         )"
#       )

    end


    def to_json( data )

      hash = Hash.new

      data.each do |k|
        # "Variable_name"=>"Innodb_buffer_pool_pages_free", "Value"=>"1"
        hash[k['Variable_name']] =  k['Value']
      end
      hash
    end

    # -- dns ------------------------------------
    #
    def create_dns( params = {} )

      return false unless( @client )

#       logger.debug( " create_dns( #{params} )")

      ip    = params.dig(:ip)
      name  = params.dig(:short)
      fqdn  = params.dig(:fqdn)

      statement = sprintf('SELECT count(ip) as count FROM dns WHERE ip = \'%s\' or name = \'%s\' or fqdn = \'%s\'', ip, name, fqdn )
      result    = @client.query( statement, :as => :hash )

#       logger.debug( statement )
#      logger.debug( result.to_a )

      if( result.to_a.first.dig('count').to_i == 0 )

        statement = sprintf('insert into dns ( ip, name, fqdn, status ) values ( \'%s\', \'%s\', \'%s\', \'prepare\' )', ip, name, fqdn )
        @client.query( statement, :as => :hash )

#         logger.debug( statement )
#         logger.debug( result.to_a )
      end
    end


    def remove_dns( params = {} )

      return false unless( @client )

#       logger.debug( " removeDNS( #{params} )")
      ip    = params.dig(:ip)
      name  = params.dig(:short)
      fqdn  = params.dig(:fqdn)

      statement = sprintf('delete FROM dns WHERE ip = \'%s\' or name = \'%s\' or fqdn = \'%s\'', ip, name, fqdn )
      result    = @client.query( statement, :as => :hash )

#       logger.debug( statement )
#      logger.debug( result.to_a )
    end


    def dns_data( params = {}  )

      return false unless( @client )

#       logger.debug( " dnsData( #{params} )")

      ip    = params.dig(:ip)
      name  = params.dig(:short)
      fqdn  = params.dig(:fqdn)

      statement = sprintf('SELECT ip, name, fqdn FROM dns WHERE ip = \'%s\' or name = \'%s\' or fqdn = \'%s\'', ip, name, fqdn )
      result    = @client.query( statement, :as => :hash )

#       logger.debug( statement )

      if( result.count != 0 )

        headers = result.fields # <= that's an array of field names, in order
        result.each(:as => :hash) do |row|
          return row
        end
      end

      nil

    end
    #
    # -- dns ------------------------------------


    #
    #
    # @return nil or Hash
    #
    def nodes( params = {} )

      return false unless( @client )

      result = Array.new
      ip     = params.dig(:ip)
      name   = params.dig(:short)
      fqdn   = params.dig(:fqdn)
      status = params.dig(:status) # Database::ONLINE or [ Storage::MySQL::ONLINE, Storage::MySQL::PREPARE ]

#       logger.debug( " nodes( #{params} )")

      if( ip == nil && name == nil && fqdn == nil )
        statement = 'select ip, name, fqdn, status from dns where 1 '
      else

        statement = sprintf(
          'select ip, name, fqdn, status from dns where ip = \'%s\' or name = \'%s\' or fqdn = \'%s\' ',
          ip,
          name,
          fqdn
        )

      end

      w = Array.new

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
#         w = sprintf( 'where %s', w )
      else
        w = nil
      end

      statement = sprintf(
        '%s and ( %s )',
        statement, w
      )

      res = self.exec( statement )

#       begin
#
#         retries ||= 1
#
#         res    = @client.query( statement, :as => :hash )
#
#         logger.info( sprintf( ' %d try to execute statement', retries ) )
#       rescue
#
#         if( retries < 5 )
#
#           sleep( 3 )
#           retries += 1
#           retry
#         end
#       end

      if( res != nil && res.size != 0 )

        headers = res.fields # <= that's an array of field names, in order
        res.each(:as => :hash) do |row|

          result << row.dig('fqdn')
        end

        return result
      end

      nil

    end


    def set_status( params = {} )

      return false unless( @client )

      ip     = params.dig(:ip)
      name   = params.dig(:short)
      fqdn   = params.dig(:fqdn)
      status = params.dig(:status) # Database::ONLINE

#       logger.debug( " setStatus( #{params} )")

      if( ip == nil )

        dns = self.dns_data( params )

        if( dns != nil )
          ip   = dns.dig('ip')
        else

          return false
        end
      end

      unless( status.nil? )

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

        res = self.exec( statement )

#        result    = @client.query( statement, :as => :hash )

#         logger.debug( statement )
#         logger.debug( result.to_a )

        return true
      end

      nil

    end


    def status( params = {} )

      return false unless( @client )

      ip    = params.dig(:ip)
      name  = params.dig(:short)
      fqdn  = params.dig(:fqdn)

#       logger.debug( " status( #{params} )")

      statement = sprintf('select ip, name, fqdn, status, creation from dns where ip = \'%s\' or name = \'%s\' or fqdn = \'%s\'', ip, name, fqdn )
      result    = @client.query( statement, :as => :hash )

#       logger.debug( statement )

      if( result.count != 0 )

        headers = result.fields # <= that's an array of field names, in order
        result.each(:as => :hash) do |row|
          return row
        end
      end

      nil
    end


    # -- configurations -------------------------
    #
    def create_config( params = {} )

      return false unless( @client )

      ip     = params.dig(:ip)
      name   = params.dig(:short)
      fqdn   = params.dig(:fqdn)
      key    = params.dig(:key)
      values = params.dig(:value)
      data   = params.dig(:data)

#       logger.debug( " createConfig( #{params} )")

      if( ( key == nil && values == nil ) && data.is_a?( Hash ) )

        data.each do |k,v|

          self.write_config( { ip: ip, short: name, fqdn: fqdn, key: k, value: v } )
        end
      else

        self.write_config( params )
      end

      nil

    end

    # PRIVATE
    def write_config( params = {} )

      ip     = params.dig(:ip)
      name   = params.dig(:short)
      fqdn   = params.dig(:fqdn)
      key    = params.dig(:key)
      values = params.dig(:value)
      data   = params.dig(:data)

#       logger.debug( " writeConfig( #{params} )")
      if( key == nil || values == nil )
        return false
      end

      if( ip == nil )

        dns = self.dns_data( params )

        if( dns != nil )
          ip   = dns.dig('ip')
        else

          return false
        end
      end

      statement = sprintf(
        'replace into config ( `key`, `value`, dns_ip ) values ( \'%s\', \'%s\', \'%s\' )',
        key, values, ip
      )

      begin
        result    = @client.query( statement, :as => :hash )

        return true
      rescue => e
        logger.error( e )
      end

      nil

    end


    def remove_config( params = {} )

      return false unless( @client )

      ip    = params.dig(:ip)
      name  = params.dig(:short)
      fqdn  = params.dig(:fqdn)
      key   = params.dig(:key)

#       logger.debug( " removeConfig( #{params} )")

      dns = self.dns_data( params )

      unless( dns.nil? )

        more = nil
        ip   = dns.dig('ip')
#         more = nil
#         logger.debug( ip )

        more = sprintf( 'and `key` = \'%s\'', key ) unless( key.nil? )

        statement = sprintf(
          'delete
            from config
          where
            dns_ip = \'%s\'
            %s',
          ip, more
        )

#         logger.debug( statement )

        begin
          result    = @client.query( statement, :as => :hash )
          return true
        rescue => e
          logger.error( e)
          return false
        end

      end

      nil
    end


    def config( params = {} )

      return false unless( @client )

      ip     = params.dig(:ip)
      name   = params.dig(:short)
      fqdn   = params.dig(:fqdn)
      key    = params.dig(:key)

      result = nil

#       logger.debug( " config( #{params} )")

      statement = sprintf(
        'select d.fqdn, c.`key`, c.`value` from dns as d, config as c where d.ip = c.dns_ip'
      )

      if( key != nil )
        statement = sprintf( '%s and `key` = \'%s\'', statement, key )
      end

      statement = sprintf(
        '%s and ( ip = \'%s\' or name = \'%s\' or fqdn = \'%s\' )',
        statement,
        ip,
        name,
        fqdn
      )

#       logger.debug( statement )

      r    = @client.query( statement, :as => :hash )

      if( r.size == 0 )

#         logger.debug( 'no result' )
        return nil
      end

      array   = Array.new
      result  = Hash.new

      r.each do |row|

        fqdn  = row.dig('fqdn')
        key   = row.dig('key')
        value = row.dig('value')

        result[key.to_s] ||= self.parsed_response(value )

      end

      result

    end
    #
    # -- configurations -------------------------

    # -- discovery ------------------------------
    #
    def create_discovery( params = {}, append = false )

      return false unless( @client )

      ip      = params.dig(:ip)
      name    = params.dig(:short)
      fqdn    = params.dig(:fqdn)
      port    = params.dig(:port)
      service = params.dig(:service)
      data    = params.dig(:data)

#       logger.debug( " createDiscovery( #{params}, #{append} )")
      if( ip == nil )

        dns = self.dns_data( { ip: ip, short: name, fqdn => fqdn } )

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

          self.write_discovery( { ip: ip, short: name, fqdn: fqdn, port: port, service: k, data: v } )
        end
      else

        params['ip']   = ip
        params['fqdn'] = fqdn

        self.write_discovery( params )
      end

      nil

    end

    # PRIVATE
    def write_discovery( params = {} )

      ip      = params.dig(:ip)
      name    = params.dig(:short)
      fqdn    = params.dig(:fqdn)
      port    = params.dig(:port)
      service = params.dig(:service)
      data    = params.dig(:data)

      statement = sprintf(
        'replace into discovery ( port, service, data, dns_ip ) values ( %s, \'%s\', \'%s\', \'%s\' )',
        port, service, data.to_s, ip
      )

      begin
        result    = @client.query( statement, :as => :hash )

        return true
      rescue => e
        puts e
#         logger.error( e )
      end

      nil

    end


    def discovery_data( params = {} )

      return false unless( @client )

      ip        = params.dig(:ip)
      name      = params.dig(:short)
      fqdn      = params.dig(:fqdn)
      service   = params.dig(:service)
      result    = Hash.new
      statement = nil

#       logger.debug( " discoveryData( #{params} )")

      # constrains are the IP
      #
      if( ip == nil )

        dns = self.dns_data( params )

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

        puts( '( service == nil && name == nil )' )
#         logger.error( '( service == nil && name == nil )' )
        return false
      end

      #  { :short => 'monitoring-16-01', :service => 'replication-live-server' }
      if( service != nil )

        statement = sprintf(
          'select
            dns.ip, dns.name, dns.fqdn, d.port, d.service, d.data
          from dns, discovery as d
          where
            dns.ip = d.dns_ip and
            d.`service` = \'%s\' and (
              dns.ip = \'%s\' or dns.name = \'%s\' or dns.fqdn = \'%s\'
            )',
          service, ip, name, fqdn
        )
      elsif( service == nil )

        statement = sprintf(
          'select
            dns.ip, dns.name, dns.fqdn, d.port, d.service, d.data
          from dns, discovery as d
          where
            dns.ip = d.dns_ip and (
              dns.ip = \'%s\' or dns.name = \'%s\' or dns.fqdn = \'%s\'
            )',
          ip, name, fqdn
        )

        r = Array.new
#         logger.debug( statement )
        res     = @client.query( statement, :as => :hash )

        if( res.count != 0 )

          headers = res.fields # <= that's an array of field names, in order
          res.each(:as => :hash) do |row|

            name     = row.dig('name').to_s
            fqdn     = row.dig('fqdn').to_s
            service  = row.dig('service').to_s
            dns_ip    = row.dig('dns_ip').to_i
            data     = row.dig('data')

            if( data == nil )
              next
            end

            data = data.gsub( '=>', ':' )
            data = self.parsed_response(data )

            result[service.to_s] = data
          end

          if( result.is_a?( Array ) )
            result = Hash[*result]
          end

          return result
        end

        return nil

      end

      nil

    end
    #
    # -- discovery ------------------------------


    # -- measurements ---------------------------
    #
    def create_measurements( params = {} )

      return false unless( @client )

      ip        = params.dig(:ip)
      name      = params.dig(:short)
      fqdn      = params.dig(:fqdn)
      data      = params.dig(:data)
      result    = Hash.new

#       logger.debug( " createMeasurements( #{params} )")


      nil
    end


    # PRIVATE
    def write_measurements( params = {} )

      ip      = params.dig(:ip)
      name    = params.dig(:short)
      fqdn    = params.dig(:fqdn)
      port    = params.dig(:port)
      service = params.dig(:service)
      data    = params.dig(:data)

      statement = sprintf(
        'replace into measurements ( discovery_port, discovery_service, measurements, dns_ip ) values ( %s, \'%s\', \'%s\', \'%s\' )',
        port, service, data.to_s, ip
      )

      begin
        result    = @client.query( statement, :as => :hash )

        return true
      rescue => e
        puts e
#         logger.error( e )
      end

      nil

    end


    def measurements( params = {} )

      return false unless( @client )

      ip        = params.dig(:ip)
      name      = params.dig(:short)
      fqdn      = params.dig(:fqdn)
      service   = params.dig(:service)
      result    = Hash.new

#       logger.debug( " measurements( #{params} )")

      # should be inpossible!
      #
      if( service == nil && name == nil )

#         logger.error( '( service == nil && name == nil )' )
        return false
      end

      # select m.measurements, d.* from discovery as d, measurements as m, dns where dns.ip = m.dns_ip

      if( service == nil )

        statement = sprintf(
          'select
            m.measurements,
            dns.ip, dns.name, dns.fqdn, d.port, d.service
          from discovery as d, measurements as m, dns
          where
            dns.ip = m.dns_ip and
            d.service = m.discovery_service and (
              dns.ip = \'%s\' or dns.name = \'%s\' or dns.fqdn = \'%s\'
            )',
          ip, name, fqdn
        )

        r = Array.new
#         logger.debug( statement )

        res     = @client.query( statement, :as => :hash )

        if( res.count != 0 )

          headers = res.fields # <= that's an array of field names, in order
          res.each(:as => :hash) do |row|

            name     = row.dig('name').to_s
            fqdn     = row.dig('fqdn').to_s
            service  = row.dig('service').to_s
            dns_ip    = row.dig('dns_ip').to_i
            data     = row.dig('data')

            if( data == nil )
              next
            end

            data = data.gsub( '=>', ':' )
            data = self.parsed_response(data )

            result[service.to_s] = data
          end

          if( result.is_a?( Array ) )
            result = Hash[*result]
          end

          return result
        end

        return nil

      end


      nil
    end
    #
    # -- measurements ---------------------------




    def parsed_response(r )

      return JSON.parse( r )
    rescue JSON::ParserError => e
      return r # do smth

    end

    def exec( statement )

#       logger.debug( "exec( #{statement} )" )

      result = nil

      begin
        retries ||= 1

        result = @client.query( statement, :as => :hash )

#         logger.debug( sprintf( ' %d try to execute statement', retries ) )
      rescue

        if( retries < 5 )

          sleep( 2 )
          retries += 1
          retry
        end
      end

#       logger.debug( result.class.to_s )
#       logger.debug( result.inspect )
#       logger.debug( result.size )

      result

    end

    #
    # -- configurations -------------------------

  end


end

# ---------------------------------------------------------------------------------------

# EOF
