#= require raphael-1.5.2.js
#= require elycharts-2.1.4.min.js
class Dashing.Sonar extends Dashing.Widget

  ready: ->

  onData: (data) ->
    samples = data.samples
    tooltips = new Array(samples)
    labels = new Array(samples)
    index = 0
    while index <= samples
      tooltips[index] = "<div class='sonartooltip'><div class='sonartooltipvalue'>" + data.values[index] + "</div><div class='sonartooltipdate'>" + data.tooltips[index] + "</div></div>"
      labels[index] = index++

    $(@node).find(".sonargraph").chart
      template: "sonar_template"
      tooltips: tooltips
      values:
        serie1: data.normalized
      labels: labels


$.elycharts.templates["sonar_template"] =
  type: "line"
  style:
    "background-color": "#12b0c5"
  height: 130
  margins: [40, 0, 0, 0]
  defaultSeries:
    rounded: 0.6
    fill: true
    stacked: false
    plotProps:
      "stroke-width": 3

    dot: true
    dotProps:
      stroke: "#5AF"
      "stroke-width": 2
      fill: "black"

    startAnimation:
      active: true
      type: "grow"
      speed: 1000
      delay: 100
      easing: "bounce"

    highlight:
      scaleSpeed: .5
      scaleEasing: "elastic"
      delay: 1000
      scale: 1.4

    tooltip:
      height: 50
      width: 100
      padding: [3, 3]
      offset: [-15, -10]
      frameProps:
        opacity: 0.75
        fill: "black"
        stroke: "white"

  series:
    serie1:
      color: "#FF8A00"

  defaultAxis:
    labels: false
    labelsProps:
      fill: "#5AF"
      "font-size": "12px"
    labelsDistance: 14

  axis:
    l:
      labels: true

  features:
    mousearea:
      type: "axis"

    tooltip:
      positionHandler: (env, tooltipConf, mouseAreaData, suggestedX, suggestedY) ->
        [mouseAreaData.event.pageX, mouseAreaData.event.pageY, true]

    grid:
      draw: false # [true, false]
      forceBorder: false
      ny: 5
      props:
        opacity: 0.6
        stroke: "#5AF" # color for the grid if drawn
