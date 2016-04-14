#
# lib/chefnodes.rb

# ----------------------------------------------------------------------------

require 'rubygems'
require 'chef/config'
require "chef/server_api"
require 'chef/search/query'

# ----------------------------------------------------------------------------

class ChefNodes

  def initialize( knifeRB = nil )

    file = File.open( '/tmp/dashing-chefnodes.log', File::WRONLY | File::APPEND | File::CREAT )
    @log = Logger.new( file, 'weekly', 1024000 )
    @log.level = Logger::DEBUG
    @log.datetime_format = "%Y-%m-%d %H:%M:%S"
    @log.formatter = proc do |severity, datetime, progname, msg|
      "[#{datetime.strftime(@log.datetime_format)}] #{severity.ljust(5)} : #{msg}\n"
    end

    if( !knifeRB )
      @log.error( 'No knife.rb given' )
    end

    Chef::Config.from_file(File.expand_path( knifeRB ))

    @chef_server_rest = chef_server_rest

    # exclude Nodes
    @excludePattern = "presales"

    @critical_timespan = (1800 + 300.0 + 180)

    @nodes_test   = {}
    @nodes_stage  = {}
    @nodes_stable = {}

  end

  def chef_server_rest
    # for saving node data we use validate_utf8: false which will not
    # raise an exception on bad utf8 data, but will replace the bad
    # characters and render valid JSON.
    @chef_server_rest ||= Chef::ServerAPI.new(
      Chef::Config[:chef_server_url],
      client_name: Chef::Config[:node_name],
      signing_key_filename: Chef::Config[:client_key],
      validate_utf8: false
    )
  end

  # get ALL Nodes from Chef-Server
  def allNodes

    opts = {
      filter_result: {
        name: ["name"],
        ipaddress: ["ipaddress"],
        ohai_time: ["ohai_time"],
        chef_environment: ["chef_environment"]
      }
    }

    all_nodes = []
    q = Chef::Search::Query.new
  #  Chef::Log.info("Sending query: #{@query}")
    q.search( :node, '*:*', opts ) do |node|
      all_nodes << node
    end

    @log.debug( 'we got ' + all_nodes.count.to_s + ' nodes' )

    return all_nodes
  end

  # use Filter Rules
  def filter( nodes )

    # entferne alle Nodes ohne IP
    @log.debug( 'remove Nodes without IP Address' )
    nodes.reject! { |i| i['ipaddress'].nil? }

    # entferne alle Nodes in 'excludePattern'
    @log.debug( 'use exclude Filter' )
    nodes.reject! { |i| i['name'] =~ /^#{@excludePattern}/i }

    # sortiere nach 'chef_environment' und 'ohai_time'
    @log.debug( 'sort Nodes' )
    nodes.sort! { |a, b| [a['chef_environment'], a['ohai_time']] <=> [b['chef_environment'], b['ohai_time']] }

    # filtere alle Nodes aus, die unter unserem Schwellwert liegen
    @log.debug( 'remove healthy nodes' )
    nodes.select! { |i| ( Time.now - Time.at( i['ohai_time'] ) ) > @critical_timespan }

    @log.info( 'got Nodes for Environment \'test\'' )
    @nodes_test   = testAvailability( environmentFilter( 'test'   , nodes ) )

    @log.info( 'got Nodes for Environment \'staging\'' )
    @nodes_stage  = testAvailability( environmentFilter( 'staging', nodes ) )

    @log.info( 'got Nodes for Environment \'stable\'' )
    @nodes_stable = testAvailability( environmentFilter( 'stable' , nodes ) )

  end


  def environmentFilter( env, nodes )

    @log.debug( 'filter for Environment ' + env )

    return nodes.select { |i| i['chef_environment'] == env }

  end


  def testAvailability( nodes )

    count = nodes.count

    @log.debug( 'test availability of ' + count.to_s + ' nodes' )

    if( count == 0 )
      @log.debug( '0 nodes are unhealty' )
      return nodes
    end

    nodes.delete_if { |x| nodeExists?( x['ipaddress'] ) == false }

    @log.debug( nodes.count.to_s + ' nodes are unhealty' )

    return nodes
  end

  # check if Node exists
  # result @bool
  def nodeExists?( ip )

    @log.debug( '  test ip ' + ip.to_s )

    # first, ping check
    if( system( 'ping -c1 -w1 ' + ip.to_s + ' > /dev/null' ) == true )

      @log.debug( '    true' )
      return true
    else
      @log.debug( '    false' )
      return false
    end

  end


  def run

    @log.info( 'starting ...' )

    @nodes = filter( allNodes )

#    @log.debug( 'now, we have ' + @nodes.count.to_s + ' nodes' )
    @log.info( 'done ...' )

  end

  def status( env )

    if( env == 'test' )
      return @nodes_test
    elsif( env == 'stage' )
      return @nodes_stage
    elsif( env == 'stable' )
      return @nodes_stable
    else
      return nil
    end
  end

end

# ----------------------------------------------------------------------------
