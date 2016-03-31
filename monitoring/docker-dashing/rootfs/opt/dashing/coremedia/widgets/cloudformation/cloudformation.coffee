
# Dashing.on 'ready', ->
#  Dashing.debugMode = true

class Dashing.Cloudformation extends Dashing.Widget

  onData: (data) ->
    if data.state == 'red'
      $(@node).css('background-color', '#a73737')
    else if data.state == 'green'
      $(@node).css('background-color', '#03A06E')

