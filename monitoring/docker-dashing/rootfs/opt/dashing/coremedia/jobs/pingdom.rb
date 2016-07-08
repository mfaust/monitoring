#
# dashing job for Pingdom
#
# Version 0.1
#
# (c) 2016 Coremedia - Bodo Schulz <bodo.schulz@coremedia.com>
#

api_key  = ENV['PINGDOM_API']  || ''
user     = ENV['PINGDOM_USER'] || ''
password = ENV['PINGDOM_PASS'] || ''

require './lib/pingdom'

p = PingDom.new( api_key, user, password )

SCHEDULER.every '5m', :first_in => 0 do

  send_event('pingdom', { checks: p.data })

end

# -------------------------
