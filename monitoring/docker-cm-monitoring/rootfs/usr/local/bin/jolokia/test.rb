
require 'logger'
require 'json'

require './lib/discover'
require './lib/jolokia-data-raiser'
require './lib/collectd-plugin'
require './lib/grafana'

def discover

  # host = 'master-16-tomcat'
  # ports = [3306,5432,28017,38099,40099,40199,40299,40399,40499,40599,40699,40799,40899,40999,41099,41199,41299,41399,42099,42199,42299,42399,42499,42599,42699,42799,42899,42999,43099,44099,45099,46099,47099,49099]
  #
  h = Discover.new()

#  puts h.listHosts()
#  status =  h.listHosts( '192.168.252.100' )

#  status = h.addHost( '192.168.252.100' )
#  status = h.addHost( '192.168.252.100', [], true )

#  puts status
#  puts h.status
 # puts h.message

  # h.addHost( 'monitoring-16-01' )
  # h.addHost( 'blackbox' )

end

def dataRaiser()

  r = JolokiaDataRaiser.new( 'config/cm-application.json', 'config/cm-service.json' )

  r.run()

  return

  pid = fork do
    stop = false
    Signal.trap('INT') { stop = true }
    until stop
      # do your thing
      r.run()
      sleep(15)
    end
  end

end

def icinga()

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
  status = i.listHost()
  puts status

  # d = Discover.new()
  status = d.listHosts( '192.168.252.100' )

  if( status.to_s != '' )

    if( [200,201].include?( d.status ) )

      services = d.services

      services.each do |s,v|

        port = v['port'].to_s

        services[s]['running'] = true

        if( port.match( /^.[0-9][0-9]99$/ ) )
          services[s]['port_jmx']  = services[s]['port']
          services[s]['http_port'] = services[s]['port'].to_s.gsub( '99', '80')
          services[s].delete( 'port' )
        end
      end
    end

    services['aws']  = false
    services['nrpe'] = false

#    puts JSON.pretty_generate( services )

    puts( i.addHost( '192.168.252.100', services ) )

  end

#  puts( i.applicationData() )
#  puts( i.listHost( '192.168.252.100' ) )

#  puts( '-----------------------------------------------------' )
#  puts( i.listHost( 'monitoring-16-01' ) )
#  # puts( i.deleteHost( 'monitoring-16-01' ) )
#
#  puts( i.addHost( 'monitoring-16-01', vars ) )
#
#  i.addServices( 'monitoring-16-01', services )
#
#  puts( '-----------------------------------------------------' )
#


end

def collectedPlugin()

  c = CollecdPlugin.new()

  c.run()

end

def grafana

  options = {
    'debug'   => true,
    'timeout' => 3,
    'ssl'     => false
  }
  g = Grafana::Client.new( 'localhost', 80, 'admin', 'admin', options )

#   puts g.get_all_users()
#   puts g.get_data_sources()

end


# discover
# dataRaiser
collectedPlugin
# icinga

grafana


