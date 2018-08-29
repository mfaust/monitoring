
require 'mini_cache'

module DataCollector

  class Prepare

    include Logging

    def initialize( settings )

      redis          = settings.dig(:redis)
      config         = settings.dig(:config)

      @cfg           = config.clone unless( config.nil? )
      @redis         = redis.clone  unless( redis.nil? )
      @cache         = MiniCache::Store.new()
    end


    def merge_solr_cores( metrics, cores = [] )

      work = []

      cores.each do |core|

        metric = Marshal.load( Marshal.dump( metrics ) )

        metric.each do |m|
          mb = m['mbean']
          mb.sub!( '%CORE%', core )
        end

        work.push( metric )
      end

      work.flatten!
    end

    # merge Data between Property Files and discovered Services
    # creates mergedHostData.json for every Node
    def build_merged_data( params )

#      logger.debug( "build_merged_data( #{params} )" )

      short = params.dig(:hostname)
      fqdn  = params.dig(:fqdn)
      data  = params.dig(:data)
      force = params.dig(:force) || false

      return { status: 404, message: 'no hostname given' } if( fqdn.nil? )
      return { status: 404, message: 'no discovery data given' } if( data.nil? || data == false || data.count() == 0 )

      # check our cache for prepared data
      #
      prepared   = @cache.get( fqdn )

      if( force == false )
        return { status: 200, message: 'prepared data already created' } unless( prepared.nil? )
      end
      #
      # ----------------------------------

      start = Time.now

      #
      applications = @cfg.jolokiaApplications.clone

      redis_data = []

      data.each do |service,payload|

        if( !payload.is_a?( Hash ) )
          logger.error( " => #{service} - wrong format for payload!" )
          next
        end

        result      = self.merge_data( service.to_s, applications, payload )

        redis_data << { service.to_s => result }
      end

      redis_data = redis_data.deep_string_keys

      # http://stackoverflow.com/questions/11856407/rails-mapping-array-of-hashes-onto-single-hash
      # mapping array of hashes onto single hash
      redis_data = redis_data.reduce( {} , :merge )
      redis_data_keys          = redis_data.keys.sort
      redis_data_keys_count    = redis_data_keys.count

      key = redis_data_keys.clone
      key = redis_data_keys.to_s if( redis_data_keys.is_a?(Array) )

      redis_data_keys_checksum = Digest::MD5.hexdigest( key )

      validate_data = { prepared: true, fqdn: fqdn, count: redis_data_keys_count, keys: redis_data_keys, checksum: redis_data_keys_checksum }

      # this part is needed by
      #   DataCollector::Tools.config_data()
      @redis.createMeasurements( short: short, fqdn: fqdn, data: redis_data )

      @cache.set( fqdn, 'prepared', expires_in: 320 )
      @cache.set( format( '%s-validate', fqdn ) , expires_in: 320 ) { MiniCache::Data.new( validate_data ) }

      finish = Time.now
      logger.info( sprintf( 'build prepared data in %s seconds', (finish - start).round(2) ) )

      return { status: 200 }
    end


    def merge_data( service, applications, data = {} )

      logger.debug( "merge_data( #{service} )" )

      metrics_tomcat     = applications.dig('tomcat')      # standard metrics for Tomcat

      return {} if( metrics_tomcat.nil? )

      configured_application = applications.keys

      logger.debug( '----------------------------------------------------------------------')
      logger.debug( "look for service: '#{service}'" )
      logger.debug( "configured Applications: #{configured_application}" )
#       logger.debug( data )

      data_source = nil

      # logger.debug( 'no data to merge' )
      return {} if( data.nil? || data.count() == 0 )

      if( data.dig(:data).nil? )

        application = data.dig('application')
        solr_cores  = data.dig('cores')
        metrics     = data.dig('metrics')

        data_source  = 'redis'
      else

        application = data.dig(:data, 'application')
        solr_cores  = data.dig(:data, 'cores')
        metrics     = data.dig(:data, 'metrics')

        data_source  = 'sqlite'
      end

      logger.debug( "data source: '#{data_source}'" )
      logger.debug( "application: '#{application}'" )
# logger.debug( "solr_cores : '#{solr_cores}'" )
# logger.debug( "metrics    : '#{metrics}'" )
      logger.debug( '----------------------------------------------------------------------')

      if( data_source == 'redis' )
        data['metrics'] ||= []
      else
        data[:data]            ||= {}
        data[:data]['metrics'] ||= []
      end

#       logger.debug( data )

      if( configured_application.include?( service ) )

        logger.debug( "found #{service} in tomcat application" )

        if( data_source == 'redis' )
          data['metrics'].push( metrics_tomcat.dig('metrics') )
          data['metrics'].push( applications.dig( service, 'metrics' ) )
        else
          data[:data]['metrics'].push( metrics_tomcat.dig('metrics') )
          data[:data]['metrics'].push( applications.dig( service, 'metrics' ) )
        end
      end


      if( application != nil )

        if( data_source == 'redis' )
          data['metrics'].push( metrics_tomcat.dig( 'metrics' ) )
        else
          data[:data]['metrics'].push( metrics_tomcat.dig( 'metrics' ) )
        end

        application.each do |a|

          if( applications.dig( a ) != nil )

            logger.debug( "  add application metrics for #{a}" )

            applicationMetrics = applications.dig( a, 'metrics' )

            if( solr_cores != nil )

              if( data_source == 'redis' )
                data['metrics'].push( self.merge_solr_cores( applicationMetrics , solr_cores ) )
              else
                data[:data]['metrics'].push( self.merge_solr_cores( applicationMetrics , solr_cores ) )
              end
            end

            # remove unneeded Templates
            applications[a]['metrics'].delete_if {|key| key['mbean'].match( '%CORE%' ) }

#            data[:data]['metrics'].push( metrics_tomcat['metrics'] )
            if( data_source == 'redis' )
              data['metrics'].push( applicationMetrics )
            else

              data[:data]['metrics'].push( applicationMetrics )
            end
          end
        end

      end


      if( data_source == 'redis' )

        data['metrics'].compact!   # remove 'nil' from array
        data['metrics'].flatten!   # clean up and reduce depth

        return data

      else
        data[:data]['metrics'].compact!   # remove 'nil' from array
        data[:data]['metrics'].flatten!   # clean up and reduce depth

        return data[:data]
      end

    end


    def valid_data( fqdn )

      data  = @cache.get( format( '%s-validate', fqdn ) ) || nil

      { count: 0, checksum: '', keys: '' } if( data.nil? )

      logger.debug( "valid_data: #{data} (#{data.class.to_s})" )

      count = 0
      checksum = ''
      keys = ''

      unless( data.nil? )
        count    = data.dig(:count)
        checksum = data.dig(:checksum)
        keys     = data.dig(:keys)
      end

      { count: count, checksum: checksum, keys: keys }
    end


  end

end

