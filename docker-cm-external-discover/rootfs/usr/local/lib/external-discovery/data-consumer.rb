
require 'aws-sdk'

# -----------------------------------------------------------------------------

module ExternalDiscovery

  class DataConsumer

    include Logging

    attr_reader :awsData

    def initialize( settings )

      @filter  = settings.dig(:filter)
      @region  = settings.dig(:aws, :region) || 'us-east-1'

      logger.info( '-----------------------------------------------------------------' )
      logger.info( ' CoreMedia - External Discovery Service - AWS Data Consumer' )
      logger.info( '-----------------------------------------------------------------' )
      logger.info( '' )

      begin
        @awsClient = Aws::Ec2::Client.new( { :aws => { :region => 'us-east-1' } } )
        @awsData   = Hash.new()

        # run internal scheduler to remove old data
        scheduler = Rufus::Scheduler.new

        scheduler.every( 45, :first_in => 5 ) do
          self.getInstances()
        end
      rescue => e

        logger.error( e )
        raise e

      end

    end


    def getInstances()

      logger.info( 'get AWS instance data' )
      start = Time.now

      begin

        @awsData = @awsClient.instances( { :region => @region, :filter => @filter } )

      rescue => e
        logger.error( e )
        logger.error( e.backtrace )

        message = sprintf( 'internal error: %s', e )

        return {
          :status  => 404,
          :message => message
        }

      end

      finish = Time.now
      logger.info( sprintf( 'finished in %s seconds', finish - start ) )

    end


    def mockupData()

      # states:
#       0 : pending
#       16 : running
#       32 : shutting-down
#       48 : terminated
#       64 : stopping
#       80 : stopped

      data = [
        {
          "ip": "172.32.22.201",
          "name": "cosmos-develop-service-jumphost",
          "state": "running",
          "tags": {
            "customer": "cosmos",
            "environment": "develop",
            "instance_type": "t2.medium",
            "instance_vpc": "vpc-ff36c899",
            "tier": "service"
          },
          "uid": "i-0388354ec53784031"
        },
        {
          "ip": "172.32.31.56",
          "name": "cosmos-develop-management-cms",
          "state": "running",
          "tags": {
            "customer": "cosmos",
            "environment": "develop",
            "instance_type": "t2.large",
            "instance_vpc": "vpc-ff36c899",
            "tier": "management"
          },
          "uid": "i-0439acb7468bb04d8"
        },
        {
          "ip": "10.2.14.156",
          "name": "monitoring-16-01.coremedia.vm",
          "state": "running",
          "uid": "b595dd68-66d6-42eb-a9ea-894d526c4f14",
          "tags": {
            "customer": "moebius"
          }
        }
      ]


      return data

    end


    def instances()

      return @awsData
    end
  end

end

# ---------------------------------------------------------------------------------------
# EOF
