# cloud Formation

require './lib/chefnodes'

knife_rb     = ENV['CHEF_KNIFE_RB']  || ''


if knife_rb.empty?
  puts " => chef Job"
  puts " [E] no valid knife.rb found!"
else

  cn = ChefNodes.new( knife_rb )

  SCHEDULER.every '3m', :first_in => 0 do

    cn.run
    test   = cn.status( 'test' ).count
    stage  = cn.status( 'stage' ).count
    stable = cn.status( 'stable' ).count

    items =  Array.new

    items << { label: 'test', value: test } << { label: 'stage', value: stage } << { label: 'stable', value: stable }

    send_event( 'chef', { items: items } )

  end

end
