
module ServiceDiscovery

  module Discovery

    # discorery application
    #
    def discoverApplication( params = {} )

      host = params.dig(:fqdn)
      port = params.dig(:port)

      fixedPorts = [80,443,8081,3306,5432,9100,28017,55555]
      services   = Array.new

      if( fixedPorts.include?( port ) )

        case port
        when 80
          services.push('http_proxy')
        when 443
          services.push('https_proxy')
        when 8081
          services.push('http_server_status')
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
        #
        targetUrl = sprintf( "service:jmx:rmi:///jndi/rmi://%s:%s/jmxrmi", host, port )

        array << {
          :type      => "read",
          :mbean     => "java.lang:type=Runtime",
          :attribute => [ "ClassPath" ],
          :target    => { :url => targetUrl },
          :config    => { "ignoreErrors" => true, "ifModifiedSince" => true, "canonicalNaming" => true }
        } << {
          :type      => "read",
          :mbean     => "Catalina:type=Manager,context=*,host=*",
          :target    => { :url => targetUrl },
          :config    => { "ignoreErrors" => true, "ifModifiedSince" => true, "canonicalNaming" => true }
        } << {
          :type      => "read",
          :mbean     => "Catalina:type=Engine",
          :attribute => [ 'baseDir', 'jvmRoute' ],
          :target    => { :url => targetUrl },
          :config    => { "ignoreErrors" => true, "ifModifiedSince" => true, "canonicalNaming" => true }
        } << {
          :type      => "read",
          :mbean     => "com.coremedia:type=serviceInfo,application=*",
          :target    => { :url => targetUrl },
          :config    => { "ignoreErrors" => true, "ifModifiedSince" => true, "canonicalNaming" => true }
        }

        response       = @jolokia.post( { :payload => array } )
        responseStatus = response.dig(:status).to_i
        responseBody   = response.dig(:message)

        if( responseStatus != 200 )

#           logger.error( response )
#           logger.error( responseStatus )

          if( responseBody != nil )

            responseBody.delete!( "\t" )
            responseBody.delete!( "\n" )

            if( responseBody.include?( 'UnknownHostException' ) )
              responseBody = sprintf( 'Unknown Host: %s', host )
            end
          else

            responseBody = 'bad status'
          end

          logger.error( {
            :status  => responseStatus,
            :message => responseBody
          } )

          return nil

        else

          body = response.dig(:message)

          if( body != nil )

            runtime     = body[0]  # #1  == Runtime
            manager     = body[1]  # #2  == Manager
            engine      = body[2]  # #3  == engine
            information = body[3]  # #4  == serviceInfo

            # since 1706 (maybe), we support an special bean to give us a unique and static application name
            # thanks to Frauke!
            #
            status = information.dig('status') || 500

            if( status == 200 )

              value = information.dig('value')
              value = value.values.first
              value = value.dig('ServiceType')

              if( value != 'to be defined' )

                logger.debug( "Application are '#{value}'" )

                services.push( value )

                # clear othe results
                #
                runtime = nil
                manager = nil
                engine  = nil
              end

            end

            if( runtime != nil )

              status = runtime.dig('status') || 500
              value  = runtime.dig('value')

              if( status == 200 )

                if( value != nil )

                  classPath  = value.dig('ClassPath')

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
                    else
                      logger.error( 'parse error for ClassPath' )
                      logger.error( " => classPath: #{classPath}" )
                      logger.error( parts )
                    end

                  # cm160x - or all others
                  #
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
                    else
                      logger.error( 'parse error for ClassPath' )
                      logger.error( " => classPath: #{classPath}" )
                      logger.error( parts )
                    end
                  end

                end
              end

            end
          end

        end

        # normalize service names
        #
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
              'cae-live'
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
