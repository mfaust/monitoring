#!/usr/bin/ruby
#
# 13.09.2016 - Bodo Schulz
#
#
# v1.4.3
# -----------------------------------------------------------------------------

require 'json'
require 'yaml'
require 'fileutils'

require_relative 'logging'
require_relative 'jolokia'
require_relative 'message-queue'
require_relative 'storage'
require_relative 'tools'

# -------------------------------------------------------------------------------------------------------------------

class ServiceDiscovery

  include Logging

  def initialize( settings = {} )

    ports = [
      3306,     # mysql
      5432,     # postrgres
      9100,     # node_exporter
      28017,    # mongodb
      38099,
      40099,
      40199,
      40299,
      40399,
      40499,
      40599,
      40699,
      40799,
      40899,
      40999,
      41099,
      41199,
      41299,
      41399,
      42099,
      42199,
      42299,
      42399,
      42499,
      42599,
      42699,
      42799,
      42899,
      42999,
      43099,
      44099,
      45099,
      46099,
      47099,
      48099,
      49099,
      55555     # resourced (https://github.com/resourced/resourced)
    ]

    jolokiaHost        = settings[:jolokiaHost]       ? settings[:jolokiaHost]         : 'localhost'
    jolokiaPort        = settings[:jolokiaPort]       ? settings[:jolokiaPort]         : 8080
    mqHost             = settings[:mqHost]            ? settings[:mqHost]              : 'localhost'
    mqPort             = settings[:mqPort]            ? settings[:mqPort]              : 11300
    @mqQueue           = settings[:mqQueue]           ? settings[:mqQueue]             : 'mq-discover'

    @MQSettings = {
      :beanstalkHost => mqHost,
      :beanstalkPort => mqPort
    }

    logger.level       = Logger::DEBUG

    @serviceConfig     = settings[:serviceConfigFile] ? settings[:serviceConfigFile]   : nil
    @scanPorts         = settings[:scanPorts]         ? settings[:scanPorts]           : ports

    version             = '1.4.4'
    date                = '2017-01-30'

    logger.info( '-----------------------------------------------------------------' )
    logger.info( ' CoreMedia - Service Discovery' )
    logger.info( "  Version #{version} (#{date})" )
    logger.info( '  Copyright 2016-2017 Coremedia' )
    logger.info( '  used Services:' )
    logger.info( "    - jolokia      : #{jolokiaHost}:#{jolokiaPort}" )
    logger.info( "    - message queue: #{mqHost}:#{mqPort}/#{@mqQueue}" )
    logger.info( '-----------------------------------------------------------------' )
    logger.info( '' )

    @db                 = Storage::Database.new()
    @jolokia            = Jolokia::Client.new( { :host => jolokiaHost, :port => jolokiaPort } )

    self.readConfigurations()
  end


  def readConfigurations()

    # read Service Configuration
    #
    logger.info( 'read defines of Services Properties' )

    if( @serviceConfig == nil )
      puts 'missing service config file'
      logger.error( 'missing service config file' )
      exit 1
    end

    begin

      if( File.exist?( @serviceConfig ) )
        @serviceConfig      = YAML.load_file( @serviceConfig )
      else
        logger.error( sprintf( 'Config File %s not found!', @serviceConfig ) )
        exit 1
      end

    rescue Exception

      logger.error( 'wrong result (no yaml)')
      logger.error( "#{$!}" )
      exit 1
    end

  end


  def queue()

#     logger.debug( 'ask queue' )

    c = MessageQueue::Consumer.new( @MQSettings )

    data = c.getJobFromTube( @mqQueue )

    if( data.count() != 0 )

#       logger.debug( data )

      self.processQueue( data )
    end

  end


  def processQueue( data = {} )

    if( data.count != 0 )

      logger.info( sprintf( 'process Message from Queue %s: %d', data.dig(:tube), data.dig(:id) ) )
      logger.debug( data )

      command = data.dig( :body, 'cmd' )     || nil
      node    = data.dig( :body, 'node' )    || nil
      payload = data.dig( :body, 'payload' ) || nil

      if( command == nil )
        logger.error( 'wrong command' )
        logger.error( data )
        return
      end

      if( node == nil || payload == nil )
        logger.error( 'missing node or payload' )
        logger.error( data )
        return
      end

      result = {
        :status  => 400,
        :message => sprintf( 'wrong command detected: %s', command )
      }

      case command
      when 'add'
        logger.info( sprintf( 'add node %s', node ) )

        begin
          # TODO
          # check payload!
          # e.g. for 'force' ...
          result = self.addHost( node, payload )

          @db.setStatus( { :ip => node, :short => node, :status => isRunning?( node ) } )

          logger.debug( result )
        rescue

        end
      when 'remove'
        logger.info( sprintf( 'remove node %s', node ) )

        begin

          @db.setStatus( { :ip => node, :short => node, :status => 98 } )

          result = self.deleteHost( node )

          logger.debug( result )
        rescue

        end

      when 'refresh'
        logger.info( sprintf( 'refresh node %s', node ) )

        result = self.refreshHost( node )

        logger.debug( result )
      when 'info'
        logger.info( sprintf( 'give information for %s back', node ) )

        result = self.listHosts( node )

        self.sendMessage( { :cmd => 'info', :queue => 'mq-discover-info', :payload => result, :ttr => 1, :delay => 0 } )
      else
#         logger.error( sprintf( 'wrong command detected: %s', command ) )

        result = {
          :status  => 400,
          :message => sprintf( 'wrong command detected: %s', command )
        }

        logger.debug( result )
      end

#       result[:request]    = data

#       logger.debug( 'send message to \'mq-discover-info\'' )
#       self.sendMessage( { :cmd => 'info', :queue => 'mq-discovery-info', :payload => result } )

    end

  end


  def sendMessage( params = {} )

    cmd     = params[:cmd]     ? params[:cmd]     : nil
    node    = params[:node]    ? params[:node]    : nil
    queue   = params[:queue]   ? params[:queue]   : nil
    payload = params[:payload] ? params[:payload] : {}
    ttr     = params[:ttr]     ? params[:trr]     : 10
    delay   = params[:delay]   ? params[:delay]   : 2

    if( cmd == nil || queue == nil || payload.count() == 0 )
      return
    end

#     logger.debug( JSON.pretty_generate( payload ) )

    p = MessageQueue::Producer.new( @MQSettings )

    job = {
      cmd:  cmd,          # require
      node: node,         # require
      timestamp: Time.now().strftime( '%Y-%m-%d %H:%M:%S' ), # optional
      from: 'discovery',  # optional
      payload: payload    # require
    }.to_json

    logger.debug( JSON.pretty_generate( job ) )

    logger.debug( p.addJob( queue, job, ttr, delay ) )

  end


  def discoverApplication( host, port )

#     logger.debug( sprintf( 'discoverApplication( %s, %d )', host, port ) )

    services = Array.new

    if( port == 3306 || port == 5432 || port == 9100 || port == 28017 || port == 55555 )

      case port
      when 3306
        services.push('mysql')
      when 5432
        services.push('postgres')
      when 9100
        services.push('node_exporter')
      when 28017
        services.push('mongodb')
      when 55555
        services.push('resourced')
      end
    else

      h     = Hash.new()
      array = Array.new()

      # hash for the NEW Port-Schema
      # since cm160x every application runs in his own container with unique port schema

      targetUrl = sprintf( "service:jmx:rmi:///jndi/rmi://%s:%s/jmxrmi", host, port )

      array << {
        :type      => "read",
        :mbean     => "java.lang:type=Runtime",
        :attribute => [ "ClassPath" ],
        :target    => { :url => targetUrl },
        :config    => { "ignoreErrors" => true, "ifModifiedSince" => true, "canonicalNaming" => true }
      }

      array << {
        :type      => "read",
        :mbean     => "Catalina:type=Manager,context=*,host=*",
        :target    => { :url => targetUrl },
        :config    => { "ignoreErrors" => true, "ifModifiedSince" => true, "canonicalNaming" => true }
      }

      array << {
        :type      => "read",
        :mbean     => "Catalina:type=Engine",
        :attribute => [ 'baseDir', 'jvmRoute' ],
        :target    => { :url => targetUrl },
        :config    => { "ignoreErrors" => true, "ifModifiedSince" => true, "canonicalNaming" => true }
      }

      response       = @jolokia.post( { :payload => array } )
      responseStatus = response[:status].to_i

      if( responseStatus != 200 )

        response = response[:message]
        response.delete!( "\t" ).delete!( "\n" )

#         logger.debug( response )
#
#         regex    = [
#           /(.*)connection to:(?<host>.+[a-zA-Z0-9]);/i,
#           /(.*)Exception:(?<exception>.+\S)/i
#         ]
#
#         re = Regexp.union(regex)
#
#         all,host,exception = response.match( re ).to_a
#
#         logger.error( sprintf( '%s - %s', host.strip, exception.strip.tr('[]','') ) )
#
#         return nil

        return nil

        return {
          :status  => responseStatus,
          :message => response
        }

      else

        body = response.dig(:message)

        if( body != nil )

          # #1 == Runtime
          runtime = body[0]
          # #2  == Manager
          manager = body[1]
          # #3  == engine
          engine = body[2]

#            logger.debug( JSON.pretty_generate( runtime ) )
#            logger.debug( JSON.pretty_generate( manager ) )
#            logger.debug( JSON.pretty_generate( engine ) )

          if( runtime['status'] && runtime['status'] == 200 )

            value = runtime['value'] ? runtime['value'] : nil

            if( value != nil )

              classPath  = value['ClassPath'] ? value['ClassPath'] : nil

              if( classPath.include?( 'cm7-tomcat-installation' ) )

                logger.debug( 'found pre cm160x Portstyle (‎possibly cm7.x)' )
                value = manager['value'] ? manager['value'] : nil

                regex = /context=(.*?),/
                value.each do |context,v|

                  part = context.match( regex )

                  if( part != nil && part.length > 1 )

                    appName = part[1].gsub!( '/', '' )

                    if( appName == 'manager' )
                      # skip 'manager'
                      next
                    end

                    logger.debug( sprintf( ' - ‎recognized application: %s', appName ) )
                    services.push( appName )
                  end
                end

                logger.debug( services )

                # coremedia = cms, mls, rls?
                # caefeeder = caefeeder-preview, cae-feeder-live?
                if( ( services.include?( 'coremedia' ) ) || ( services.include?( 'caefeeder' ) ) )

                  value = engine['value'] ? engine['value'] : nil

                  if( engine['status'].to_i == 200 )

                    baseDir = value['baseDir'] ? value['baseDir'] : nil

                    regex = /
                      ^                           # Starting at the front of the string
                      (.*)                        #
                      \/cm7-                      #
                      (?<service>.+[a-zA-Z0-9-])  #
                      (.*)-tomcat                 #
                      $
                    /x

                    parts = baseDir.match( regex )

                    if( parts )
                      service = parts['service'].to_s.strip.tr('. ', '')
                      services.delete( "coremedia" )
                      services.delete( "caefeeder" )
                      services.push( service )

                      logger.debug( sprintf( '  => %s', service ) )
                    else
                      logger.error( 'unknown error' )
                      logger.error( parts )
                    end
                  else
                    logger.error( sprintf( 'response status %d', engine['status'].to_i ) )
                  end
                end

                # blueprint = cae-preview or delivery?editor
                if( services.include?( 'blueprint' ) )

                  value = engine['value'] ? engine['value'] : nil

                  if( engine['status'].to_i == 200 )

                    jvmRoute = value['jvmRoute'] ? value['jvmRoute'] : nil

                    if( ( jvmRoute != nil ) && ( jvmRoute.include?( 'studio' ) ) )
                      services.delete( "blueprint" )
                      services.push( "cae-preview" )
                    else
                      services.delete( "blueprint" )
                      services.push( "delivery" )
                    end
                  else
                    logger.error( sprintf( 'response status %d', engine['status'].to_i ) )
                  end
                end

              # cm160x - or all others
              else

                regex = /
                  ^                           # Starting at the front of the string
                  (.*)                        #
                  \/coremedia\/               #
                  (?<service>.+[a-zA-Z0-9-])  #
                  \/current                   #
                  (.*)                        #
                  $
                /x

                parts = classPath.match( regex )

                if( parts )
                  service = parts['service'].to_s.strip.tr('. ', '')
                  services.push( service )

#                   logger.debug( sprintf( '  => %s', service ) )
                else
                  logger.error( 'unknown error' )
                  logger.error( parts )
                end
              end

            end
          end

        end

      end

      # normalize service names
      services.map! {|service|

        case service
          when 'cms'
            'content-management-server'
          when 'mls'
            'master-live-server'
          when 'rls'
            'replication-live-server'
          when 'wfs'
            'workflow-server'
          when 'delivery'
            'cae-live-1'
          when 'solr'
            'solr-master'
          when 'contentfeeder'
            'content-feeder'
          when 'workflow'
            'workflow-server'
          else
            service
        end
      }

    end

    logger.debug( "  found services: #{services}" )

    return services
  end


  # merge hashes of configured (cm-service.yaml) and discovered data (discovery.json)
  def createHostConfig( data )

    data.each do |d,v|

      logger.debug( d )

      # merge data between discovered Services and our base configuration,
      # the dicovered ports are IMPORTANT
      if( @serviceConfig['services'][d] )

        logger.debug( @serviceConfig['services'][d] )

        data[d].merge!( @serviceConfig['services'][d] ) { |key, port| port }

        port       = data[d]['port']      ? data[d]['port']      : nil
        port_http  = data[d]['port_http'] ? data[d]['port_http'] : nil

        if( port != nil && port_http != nil )
          data[d]['port_http'] = ( port - 19 )
        end

      else
        logger.debug( sprintf( 'missing entry \'%s\' in cm-service.yaml for merge with discovery data', d ) )
      end
    end

    return data

  end

  # delete the directory with all files inside
  def deleteHost( host )

    logger.info( sprintf( 'delete Host \'%s\'',  host ) )

    status  = 400
    message = 'Host not in Monitoring'

    if( @db.removeDNS( { :ip => host, :short => host, :long => host } ) != nil )

      status  = 200
      message = 'Host successful removed'
    end

    return {
      :status  => status,
      :message => message
    }

  end

  # add Host and discovery applications
  def addHost( host, options = {} )

    logger.info( sprintf( 'Adding host \'%s\'', host ) )

    if( @db.discoveryData( { :ip => host, :short => host, :long => host } ) != nil )

      logger.error( 'Host already created' )

      return {
        :status  => 409,
        :message => 'Host already created'
      }

    end

    if( @jolokia.jolokiaIsAvailable?() == false )

      logger.error( 'jolokia service is not available!' )

      return {
        :status  => 500,
        :message => 'jolokia service is not available!'
      }
    end

    # create DNS Information
    hostInfo      = hostResolve( host )

    ip            = hostInfo[:ip]    ? hostInfo[:ip]    : nil
    shortHostName = hostInfo[:short] ? hostInfo[:short] : nil
    longHostName  = hostInfo[:long]  ? hostInfo[:long]  : nil

    # second, if the that we whant monitored, available
    if( isRunning?( ip ) == false )

      logger.error( 'host not running' )
      logger.debug( hostInfo )

      return {
        :status  => 400,
        :message => 'Host not available'
      }
    end

    @db.createDNS( { :ip => ip, :short => shortHostName, :long => longHostName } )

    ports = @db.config( { :ip => ip, :short => shortHostName, :long => longHostName, :key => "ports" } )

    if( ports != false )
      ports = ports.dig( shortHostName, 'ports' )
    else
      # our default known ports
      ports = @scanPorts
    end

    logger.debug( "use ports: #{ports}" )

    discover = Hash.new()
    services = Hash.new()

    open = false

    ports.each do |p|

      open = portOpen?( longHostName, p )

      logger.debug( sprintf( 'Host: %s | Port: %s   %s', host, p, open ? 'open' : 'closed' ) )

      if( open == true )

        names = self.discoverApplication( host, p )

        if( names != nil )

          names.each do |name|
            services.merge!( { name => { 'port' => p } } )
          end

        end

      end

    end

    # merge discovered services with cm-services.yaml
    services = self.createHostConfig( services )

    dns      = @db.dnsData( { :short => shortHostName } )

    if( dns == nil )
      logger.debug( 'no data for ' + shortHostName )
    else
      dnsId        = dns[ :id ]
      dnsIp        = dns[ :ip ]
      dnsShortname = dns[ :shortname ]
      dnsLongname  = dns[ :longname ]
      dnsCreated   = dns[ :created ]
      dnsChecksum  = dns[ :checksum ]

      @db.createDiscovery( {
        :id       => dnsId,
        :ip       => dnsIp,
        :short    => dnsShortname,
        :checksum => dnsChecksum,
        :data     => services
      } )

    end

    status  = 200
    message = 'Host successful created'

    @services = services

    return {
      :status  => status,
      :message => message
    }
  end


  def refreshHost( host )

    status  = 200
    message = 'initialize message'

    hostInfo = hostResolve( host )
    ip       = hostInfo[:ip] ? hostInfo[:ip] : nil

    # second, if the that we want monitored, available
    if( isRunning?( ip ) == false )

      status  = 400
      message = 'Host not available'
    end

    return {
      :status  => status,
      :message => message
    }

  end


  def listHosts( host = nil )

    hosts    = Array.new()
    result   = Hash.new()
    services = Hash.new()

    if( host == nil )

      logger.info( 'TODO - use Database insteed of File - ASAP' )
    else

      discoveryData  = @db.discoveryData( { :ip => host, :short => host } )

      if( discoveryData == nil )

        return {
          :status   => 404,
          :message  => 'no host found'
        }

      end

      hostServices   = discoveryData.dig( host )

      hostServices.each do |s|

        s.last.dig(:data).reject! { |k| k == :application }

        services[s.first.to_sym] ||= {}
        services[s.first.to_sym] = s.last.dig(:data)

      end

      status         = @db.status( { :ip => host, :short => host } )

      created        = status.dig( :created )
      created        = Time.parse( created ).strftime( '%Y-%m-%d %H:%M:%S' )

      online         = status.dig( :status )

      case online
      when 0
        status = 'offline'
      when 1
        status = 'online'
      when 98
        status = 'delete'
      when 99
        status = 'prepare'
      else
        status = 'unknown'
      end

      result = {
        :status   => status,
        :services => services,
        :created  => created
      }

#       logger.debug( JSON.pretty_generate ( result ) )

    end

    return result


    # CODE above are OBSOLETE

#     if( host == nil )
#
#       data = @db.discoveryData()
#
#       Dir.chdir( @cacheDirectory )
#       Dir.glob( "**" ) do |f|
#
#         if( FileTest.directory?( f ) )
#           hosts.push( hostInformation( f, File.basename( f ) ) )
#         end
#       end
#
#       hosts.sort!{ |a,b| a['name'] <=> b['name'] }
#
#       status  = 200
#       message = hosts
#
#       return {
#         :status  => status,
#         :hosts   => message
#       }
#
#     else
#
#       cacheDirectory  = sprintf( '%s/%s', @cacheDirectory, host )
#       discoveryFileName = 'discovery.json'
#
#       file      = sprintf( '%s/%s', cacheDirectory, discoveryFileName )
#
#       if( File.exist?( file ) == true )
#
#         data = File.read( file )
#
#         h              = hostInformation( file, File.basename( cacheDirectory ) )
#         h['services' ] = JSON.parse( data )
#
#         status   = 200
#         message  = h
#         @services = h['services']
#
#         return {
#           :status  => status,
#           :hosts   => message
#         }
#
#       else
#
#         status  = 404
#         message = 'No discovery File found'
#
#         return {
#           :status  => status,
#           :hosts   => nil,
#           :message => message
#         }
#       end
#
#     end
  end


  def hostInformation( file, host )

    status   = isRunning?( host )
    age      = File.mtime( file ).strftime("%Y-%m-%d %H:%M:%S")
    services = Hash.new()

    if( file != host )
      data   = JSON.parse( File.read( file ) )

      data.each do |d,v|

        services[d.to_s] ||= {}
        services[d.to_s] = {
          :port        => v['port'],
          :description => v['description']
        }
      end
    end

    return {
      host => {
        :status   => status ? 'online' : 'offline',
        :services => services,
        :created  => age
      }
    }

  end

end

