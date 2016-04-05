
Dashing.on 'ready', ->
 Dashing.debugMode = true

class Dashing.Cloudwatch extends Dashing.Widget

  onData: (data) ->
    console.debug( data )

    if data.state == 'red'
      $(@node).css('background-color', '#a73737')
    else if data.state == 'yellow'
      $(@node).css('background-color', '#03A06E')
    else if data.state == 'green'
      $(@node).css('background-color', '#03A06E')

#    console.debug( data.name )
#    console.debug( data.time )
#    console.debug( data.avg )
