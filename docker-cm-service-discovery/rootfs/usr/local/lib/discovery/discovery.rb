
module ServiceDiscovery

  module Discovery

    def discoverApplication( host, port )

      logger.debug( sprintf( 'discoverApplication( %s, %d )', host, port ) )

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

#           {:status=>500, :message=>"java.io.IOException : Failed to retrieve RMIServer stub: javax.naming.ConfigurationException [Root exception is java.rmi.UnknownHostException: Unknown host: master-17-tomcat; nested exception is: java.net.UnknownHostException: master-17-tomcat]"}

          if( response.include?( 'UnknownHostException' ) )
            response = sprintf( 'Unknown Host: %s', host )
          end

          logger.debug( {
            :status  => responseStatus,
            :message => response
          } )

          return nil

        else

#           logger.debug( response.class.to_s )
#           logger.debug( response )

          body = response.dig(:message)

          if( body != nil )

            # #1 == Runtime
            runtime = body[0]
            # #2  == Manager
            manager = body[1]
            # #3  == engine
            engine = body[2]

#             logger.debug( JSON.pretty_generate( runtime ) )
#             logger.debug( JSON.pretty_generate( manager ) )
#             logger.debug( JSON.pretty_generate( engine ) )

            status = runtime.dig('status') || 500
            value  = runtime.dig('value')

            if( status == 200 )

              if( value != nil )

                classPath  = value.dig('ClassPath')

                if( classPath.include?( 'cm7-tomcat-installation' ) )

                  logger.debug( 'found pre cm160x Portstyle (‎possibly cm7.x)' )
                  value = manager.dig('value')

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

                    value = engine.dig('value')

                    if( engine.dig('status').to_i == 200 )

                      baseDir = value.dig('baseDir')

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

                    value = engine.dig('value')

                    if( engine.dig('status').to_i == 200 )

                      jvmRoute = value.dig('jvmRoute')

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

#       logger.debug( "  found services: #{services}" )

      return services
    end

  end


end
