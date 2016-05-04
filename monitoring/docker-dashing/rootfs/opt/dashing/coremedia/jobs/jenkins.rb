#
# dashing job for Jenkins
#
# Version 2.0
#
# (c) 2016 Coremedia - Bodo Schulz <bodo.schulz@coremedia.com>
#

require './lib/jenkins'

j = Jenkins.new( 'config/jenkins.json' )

SCHEDULER.every '3m' do

  single   = j.singleData
  reorged  = j.reorganizeData( single )

  single.each do |d|
    send_event( d[:tag], d[:result] )
  end


end
