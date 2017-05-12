
module ServiceDiscovery

  module Discovery

    # discorery application
    #
    def discoverApplication( params = {} )

#       logger.debug( "discoverApplication( #{params} )" )

      host = params.dig( :fqdn )
      port = params.dig( :port )

      fixedPorts = [3306,5432,9100,28017,55555]
      services   = Array.new

      if( fixedPorts.include?( port ) )

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
        responseStatus = response.dig(:status).to_i

        if( responseStatus != 200 )

          response = response[:message]
          response.delete!( "\t" ).delete!( "\n" )

          if( response.include?( 'UnknownHostException' ) )
            response = sprintf( 'Unknown Host: %s', host )
          end

          logger.error( {
            :status  => responseStatus,
            :message => response
          } )

          return nil

        else

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

#                 logger.debug( "found classPath: #{classPath}" )
                #
                # CoreMedia 7.x == classPath 'cm7-tomcat-installation'
                # Solr 6.5      == classPath 'solr-6'
                # SpringBoot    == classPath '*.war'
                # others        == CoreMedia > 9
                #
                # CoreMedia 7.x Installation
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

                  # coremedia = cms, mls, rls?
                  # caefeeder = caefeeder-preview, cae-feeder-live?
                  #
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

                  # blueprint = cae-preview or delivery?editor
                  #
                  elsif( services.include?( 'blueprint' ) )

                    value = engine.dig('value')

                    if( engine.dig('status').to_i == 200 )

                      jvmRoute = value.dig('jvmRoute')

                      if( ( jvmRoute != nil ) && ( jvmRoute.include?( 'studio' ) ) )
                        services.delete( 'blueprint' )
                        services.push( 'cae-preview' )
                      else
                        services.delete( 'blueprint' )
                        services.push( 'delivery' )
                      end
                    else
                      logger.error( sprintf( 'response status %d', engine['status'].to_i ) )
                      logger.error( engine )
                    end
                  else

                    logger.warn( 'unknown service:' )
                    logger.warn( services )
                  end

                # Solr 6 Support
                #
                elsif( classPath.include?( 'solr-6' ) )

                  services.push( 'solr' )

                # CoreMedia on Cloud / SpringBoot
                #
                elsif( classPath.include?( '.war' ) )

                  regex = /
                    ^
                    \/(?<service>.+[a-zA-Z0-9-])\.war$
                  /x

                  parts = classPath.match( regex )

                  if( parts )
                    service = parts['service'].to_s.strip
                    services.push( service )

                    # BUG
                    # when we use solr-6.5, we lands here!
                    # Solr 6.5 are not a coremedia tomcat application anymore
                    logger.error( 'parse error for ClassPath' )
                    logger.error( " => classPath: #{classPath}" )
                    logger.error( parts )
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

                    # BUG
                    # when we use solr-6.5, we lands here!
                    # Solr 6.5 are not a coremedia tomcat application anymore
                    logger.error( 'parse error for ClassPath' )
                    logger.error( " => classPath: #{classPath}" )
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

      return services
    end

  end

end
