
require 'digest/md5'

require_relative '../logging'
require_relative '../monkey'

module Aws

  module Sns

    class Client

      include Logging

      def initialize( settings = {} )

        @region  = settings.dig(:aws, :region) || 'us-east-1'

        begin

          Aws.config.update( { region: @region } )

          @awsClient = Aws::EC2::Client.new()
        rescue => e

          raise e
        end

      end


      def createSubscription( params = {} )

        region    = params.dig(:region)  || @region
        accountId = params.dig(:account_id)
        topic     = params.dig(:topic)
        protocol  = params.dig(:protocol)
        endpoint  = params.dig(:endpoint)

        sns       = Aws::SNS::Resource.new( region: region )

        topic     = sns.topic( sprintf( 'arn:aws:sns:%s:%s:%s', region, accountId, topic ) ) #  'arn:aws:sns:us-west-2:123456789:MyGroovyTopic')

        sub = topic.subscribe({
          protocol: protocol,
          endpoint: endpoint
        })

        logger.debug( sub.arn )


      end


      def sendMessage( params = {} )

        # aws sns publish --topic-arn "arn:aws:sns:us-east-1:450225884721:app-monitoring" --message file://message.txt

        region    = params.dig(:region)  || @region
        accountId = params.dig(:account_id)
        topic     = params.dig(:topic)
        message   = params.dig(:message)

        sns       = Aws::SNS::Resource.new( region: region )

        topic     = sns.topic( sprintf( 'arn:aws:sns:%s:%s:%s', region, accountId, topic ) ) #  'arn:aws:sns:us-west-2:123456789:MyGroovyTopic')

        topic.publish({
          message: message
        })

      end


      def showTopics()

        region    = params.dig(:region)  || @region

        sns       = Aws::SNS::Resource.new( region: region )

        sns.topics.each do |topic|
          logger.debug( topic.arn )
        end
      end


    end

  end

end

