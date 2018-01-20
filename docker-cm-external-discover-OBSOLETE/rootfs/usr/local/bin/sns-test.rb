#!/usr/bin/ruby
#
# 01.06.2017 - Bodo Schulz
#
#
# v0.0.1

# -----------------------------------------------------------------------------

require 'yaml'

require_relative '../lib/aws/sns'

# -----------------------------------------------------------------------------

awsRegion        = ENV.fetch('AWS_REGION', 'us-east-1')

config = {
  :aws        => {
    :region  => awsRegion,
    :filter  => []
  }
}

# ---------------------------------------------------------------------------------------

s = Aws::Sns::Client.new( config )

s.create_subscription( { :protocol => 'email', :endpoint => 'bodo.schulz@coremedia.com' } )
#s.show_topics()
s.send_message( { :topic => 'app-monitoring' :account_id => '450225884721', :message => 'test-message' } )



# -----------------------------------------------------------------------------

# EOF
