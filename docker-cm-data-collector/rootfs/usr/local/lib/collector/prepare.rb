
require_relative '../cache'

module DataCollector

  class Prepare

    include Logging

    def initialize( settings = {} )

      @redisHost     = settings.dig(:redis, :host)
      @redisPort     = settings.dig(:redis, :port) || 6379

      @cfg           = Config.new( settings )
      @redis         = Storage::RedisClient.new( { :redis => { :host => @redisHost } } )
      @cache         = Cache::Store.new()

    end


    def mergeSolrCores( metrics, cores = [] )

      work = Array.new()

      cores.each do |core|

        metric = Marshal.load( Marshal.dump( metrics ) )

        metric.each do |m|
          mb = m['mbean']
          mb.sub!( '%CORE%', core )
        end

        work.push( metric )
      end

      work.flatten!

      return work
    end

    # merge Data between Property Files and discovered Services
    # creates mergedHostData.json for every Node
    def buildMergedData( params = {} )

#       logger.debug( "buildMergedData( #{params} )" )

      short = params.dig(:hostname)
      fqdn  = params.dig(:fqdn)
      data  = params.dig(:data)

      if( short == nil )
        logger.error( 'no hostname found' )
        return {}
      end

      # check our cache for prepared data
      #
      prepared   = @cache.get( short )

      if( prepared != nil )

        logger.debug( 'prepared data already created' )

        return
      end
      #
      # ----------------------------------

      start = Time.now

      #
#      tomcatApplication = Marshal.load( Marshal.dump( @cfg.jolokiaApplications ) )

#       logger.debug( tomcatApplication )

      tomcatApplication = @cfg.jolokiaApplications.clone

#       if( tomcatApplication == testData )
#         logger.debug( 'identical' )
#       end

#       if( data == nil )
#
#         # Redis based
#         logger.debug( 'use redis' )
#         data = @redis.discoveryData( { :short => short } )
#       end

      if( data == nil || data == false || data.count() == 0 )
        logger.error( 'no discovery data found' )
        return false
      end

      dataForRedis = Array.new()

      data.each do |service,payload|

        if( !payload.is_a?( Hash ) )
          logger.error( " => #{service} - wrong format for payload!" )
          next
        end

        result      = self.mergeData( service.to_s, tomcatApplication, payload )

#         logger.debug( JSON.pretty_generate( result ) )

        dataForRedis << { service.to_s => result }
      end

      dataForRedis = dataForRedis.deep_string_keys

      # http://stackoverflow.com/questions/11856407/rails-mapping-array-of-hashes-onto-single-hash
      # mapping array of hashes onto single hash
      dataForRedis = dataForRedis.reduce( {} , :merge )

      @redis.createMeasurements( { :short => short, :data => dataForRedis } )

      @cache.set( short, 'prepared', expiresIn: 320 )

      finish = Time.now
      logger.info( sprintf( 'build prepared data in %s seconds', finish - start ) )

      return true

    end


    def mergeData( service, tomcatApplication, data = {} )

      logger.debug( "mergeData( #{service} )" )

      metricsTomcat     = tomcatApplication.dig('tomcat')      # standard metrics for Tomcat

      configuredApplication = tomcatApplication.keys

#       logger.debug( '----------------------------------------------------------------------')
#       logger.debug( "look for service: '#{service}'" )
#       logger.debug( "configured Applications: #{configuredApplication}" )
#       logger.debug( data )

      dataSource = nil

      if( data == nil || data.count() == 0 )
        logger.debug( 'no data to merge' )

        return {}
      end

      if( data.dig(:data) == nil )

        application = data.dig('application')
        solr_cores  = data.dig('cores')
        metrics     = data.dig('metrics')

        dataSource  = 'redis'
      else

        application = data.dig(:data, 'application')
        solr_cores  = data.dig(:data, 'cores')
        metrics     = data.dig(:data, 'metrics')

        dataSource  = 'sqlite'
      end

# logger.debug( "data source: '#{dataSource}'" )
# logger.debug( "application: '#{application}'" )
# logger.debug( "solr_cores : '#{solr_cores}'" )
# logger.debug( "metrics    : '#{metrics}'" )
#       logger.debug( '----------------------------------------------------------------------')

      if( dataSource == 'redis' )

        data['metrics'] ||= []
      else

        data[:data]            ||= {}
        data[:data]['metrics'] ||= []
      end

#       logger.debug( data )

      if( configuredApplication.include?( service ) )

        logger.debug( "found #{service} in tomcat application" )

        if( dataSource == 'redis' )
          data['metrics'].push( metricsTomcat.dig('metrics') )
          data['metrics'].push( tomcatApplication.dig( service, 'metrics' ) )
        else
          data[:data]['metrics'].push( metricsTomcat.dig('metrics') )
          data[:data]['metrics'].push( tomcatApplication.dig( service, 'metrics' ) )
        end
      end


      if( application != nil )

        if( dataSource == 'redis' )
          data['metrics'].push( metricsTomcat.dig( 'metrics' ) )
        else
          data[:data]['metrics'].push( metricsTomcat.dig( 'metrics' ) )
        end

        application.each do |a|

          if( tomcatApplication.dig( a ) != nil )

            logger.debug( "  add application metrics for #{a}" )

            applicationMetrics = tomcatApplication.dig( a, 'metrics' )

            if( solr_cores != nil )

              if( dataSource == 'redis' )
                data['metrics'].push( self.mergeSolrCores( applicationMetrics , solr_cores ) )
              else
                data[:data]['metrics'].push( self.mergeSolrCores( applicationMetrics , solr_cores ) )
              end
            end

            # remove unneeded Templates
            tomcatApplication[a]['metrics'].delete_if {|key| key['mbean'].match( '%CORE%' ) }

#            data[:data]['metrics'].push( metricsTomcat['metrics'] )
            if( dataSource == 'redis' )
              data['metrics'].push( applicationMetrics )
            else

              data[:data]['metrics'].push( applicationMetrics )
            end
          end
        end

      end


      if( dataSource == 'redis' )

        data['metrics'].compact!   # remove 'nil' from array
        data['metrics'].flatten!   # clean up and reduce depth

        return data

      else
        data[:data]['metrics'].compact!   # remove 'nil' from array
        data[:data]['metrics'].flatten!   # clean up and reduce depth

        return data[:data]
      end

    end

  end

end

