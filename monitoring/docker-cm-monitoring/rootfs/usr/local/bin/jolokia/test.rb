
require 'logger'
require 'json'

require './lib/discover'
require './lib/jolokia'

#
#
# host = 'master-16-tomcat'
# ports = [3306,5432,28017,38099,40099,40199,40299,40399,40499,40599,40699,40799,40899,40999,41099,41199,41299,41399,42099,42199,42299,42399,42499,42599,42699,42799,42899,42999,43099,44099,45099,46099,47099,49099]
#
# h = Discover.new()
# h.addHost( '192.168.252.100' , [], true )
# h.addHost( 'monitoring-16-01', [], true )

r = JolokiaDataRaiser.new()
r.applicationConfig( 'config/application.json' )
r.serviceConfig( 'config/jolokia.json' )

pid = fork do
  stop = false
  Signal.trap('INT') { stop = true }
  until stop
    # do your thing
    r.run()
    sleep(15)
  end
end


# r.applicationConfig( 'config/application.json' )
# r.serviceConfig( 'config/jolokia.json' )
# r.run( 'config/application.json', 'config/jolokia.json' )

exit 0

require './lib/icinga2'

vars = {
  'nrpe'   => true,
  'aws'    => false,
  'studio' => true,
  'CMS'    => {
    'running'   => true,
    'port_jmx'  => 40099,
    'port_http' => 40080
  },
  'MLS'    => true
}

# attrs="$(jo display_name="CMS Heap Mem" check_command=cm_memory max_check_attempts=5 host_name=${host} vars.host=${host} vars.port=${port_jmx} vars.memory=heap-mem)"
# jo -p templates[]="generic-service" attrs="${attrs}" > ${TMP_DIR}/icinga2/service-heap-mem-${k}.json
# addIcingaService "check-cm-heap-mem-${k}" service-heap-mem-${k}.json


services = {
  'service-heap-mem-CMS' => {
    'display_name' => 'Coremedia - Heap Mem - CMS',
    'check_command' => 'cm_memory',
    'vars' => {
      'host'   => '%HOST%',
      'port'   => '40099',
      'memory' => 'heap-mem',
    }
  },
  'service-perm-mem-CMS' => {
    'display_name' => 'Coremedia - Perm Mem - CMS',
    'check_command' => 'cm_memory',
    'vars' => {
      'host'   => '%HOST%',
      'port'   => '40099',
      'memory' => 'perm-mem',
    }
  }
}



i = Icinga2.new( 'localhost', 5665, 'root', 'icinga' )

puts( i.applicationData() )

puts( '-----------------------------------------------------' )
puts( i.listHost( 'monitoring-16-01' ) )
# puts( i.deleteHost( 'monitoring-16-01' ) )

puts( i.addHost( 'monitoring-16-01', vars ) )

i.addServices( 'monitoring-16-01', services )

puts( '-----------------------------------------------------' )

# require './lib/discover'
#
#
# host = 'master-16-tomcat'
# ports = [3306,5432,28017,38099,40099,40199,40299,40399,40499,40599,40699,40799,40899,40999,41099,41199,41299,41399,42099,42199,42299,42399,42499,42599,42699,42799,42899,42999,43099,44099,45099,46099,47099,49099]
#
# h = Discover.new()
# h.run( host , ports, true )
#
#h.run( '192.168.252.100', ports )
