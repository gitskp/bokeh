_ = require "underscore"
$ = require "jquery"
Hammer = require "hammerjs"
mousewheel = require("jquery-mousewheel")($)

Model = require "../../model"
p = require "../../core/properties"
{logger} = require "../../core/logging"

class UIEvents extends Model
  type: 'UIEvents'

  @define {
    on_tap:          [ p.Instance ]
    on_doubletap:    [ p.Instance ]
    on_press:        [ p.Instance ]
    on_pan_start:    [ p.Instance ]
    on_pan:          [ p.Instance ]
    on_pan_end:      [ p.Instance ]
    on_pinch_start:  [ p.Instance ]
    on_pinch:        [ p.Instance ]
    on_pinch_end:    [ p.Instance ]
    on_rotate_start: [ p.Instance ]
    on_rotate:       [ p.Instance ]
    on_rotate_end:   [ p.Instance ]
    on_mouse_enter:  [ p.Instance ]
    on_mouse_move:   [ p.Instance ]
    on_mouse_exit:   [ p.Instance ]
    on_mouse_wheel:  [ p.Instance ]
    on_key_down:     [ p.Instance ]
    on_key_up:       [ p.Instance ]
  }

  @internal {
    plot: [ p.Instance ]
  }

  configure_hammerjs: (@plot, hit_area) ->
    @hammer = new Hammer(hit_area[0])

    # This is to be able to distinguish double taps from single taps
    @hammer.get('doubletap').recognizeWith('tap')
    @hammer.get('tap').requireFailure('doubletap')
    @hammer.get('doubletap').dropRequireFailure('tap')

    @hammer.on('doubletap', (e) => @_doubletap(e))
    @hammer.on('tap', (e) => @_tap(e))
    @hammer.on('press', (e) => @_press(e))

    @hammer.get('pan').set({ direction: Hammer.DIRECTION_ALL })
    @hammer.on('panstart', (e) => @_pan_start(e))
    @hammer.on('pan', (e) => @_pan(e))
    @hammer.on('panend', (e) => @_pan_end(e))

    @hammer.get('pinch').set({ enable: true })
    @hammer.on('pinchstart', (e) => @_pinch_start(e))
    @hammer.on('pinch', (e) => @_pinch(e))
    @hammer.on('pinchend', (e) => @_pinch_end(e))

    @hammer.get('rotate').set({ enable: true })
    @hammer.on('rotatestart', (e) => @_rotate_start(e))
    @hammer.on('rotate', (e) => @_rotate(e))
    @hammer.on('rotateend', (e) => @_rotate_end(e))

    hit_area.mousemove((e) => @_mouse_move(e))
    hit_area.mouseenter((e) => @_mouse_enter(e))
    hit_area.mouseleave((e) => @_mouse_exit(e))
    hit_area.mousewheel((e, delta) => @_mouse_wheel(e, delta))
    $(document).keydown((e) => @_key_down(e))
    $(document).keyup((e) => @_key_up(e))

  register_tool: (tool_view) ->
    et = tool_view.model.event_type
    id = tool_view.model.id
    type = tool_view.model.type

    # tool_viewbar button events handled by tool_view manager
    if not et?
      logger.debug("Button tool: #{type}")
      return

    if et in ['pan', 'pinch', 'rotate']
      logger.debug("Registering tool: #{type} for event '#{et}'")
      if tool_view["_#{et}_start"]?
        tool_view.listenTo(@, "#{et}:start:#{id}", tool_view["_#{et}_start"])
      if tool_view["_#{et}"]
        tool_view.listenTo(@, "#{et}:#{id}",       tool_view["_#{et}"])
      if tool_view["_#{et}_end"]
        tool_view.listenTo(@, "#{et}:end:#{id}",   tool_view["_#{et}_end"])
    else if et == "move"
      logger.debug("Registering tool: #{type} for event '#{et}'")
      if tool_view._move_enter?
        tool_view.listenTo(@, "move:enter", tool_view._move_enter)
      tool_view.listenTo(@, "move", tool_view["_move"])
      if tool_view._move_exit?
        tool_view.listenTo(@, "move:exit", tool_view._move_exit)
    else
      logger.debug("Registering tool: #{type} for event '#{et}'")
      tool_view.listenTo(@, "#{et}:#{id}", tool_view["_#{et}"])

    if tool_view._keydown?
      logger.debug("Registering tool: #{type} for event 'keydown'")
      tool_view.listenTo(@, "keydown", tool_view._keydown)

    if tool_view._keyup?
      logger.debug("Registering tool: #{type} for event 'keyup'")
      tool_view.listenTo(@, "keyup", tool_view._keyup)

    if tool_view._doubletap?
      logger.debug("Registering tool: #{type} for event 'doubletap'")
      tool_view.listenTo(@, "doubletap", tool_view._doubletap)

    # Dual touch hack part 1/2
    # This is a hack for laptops with touch screen who may be pinching or scrolling
    # in order to use the wheel zoom tool. If it's a touch screen the WheelZoomTool event
    # will be linked to pinch. But we also want to trigger in the case of a scroll.
    if 'ontouchstart' of window or navigator.maxTouchPoints > 0
      if et == 'pinch'
        logger.debug("Registering scroll on touch screen")
        tool_view.listenTo(@, "scroll:#{id}", tool_view["_scroll"])

  _trigger: (event_type, e) ->
    base_event_type = event_type.split(":")[0]

    # Dual touch hack part 2/2
    # This is a hack for laptops with touch screen who may be pinching or scrolling
    # in order to use the wheel zoom tool. If it's a touch screen the WheelZoomTool event
    # will be linked to pinch. But we also want to trigger in the case of a scroll.
    if 'ontouchstart' of window or navigator.maxTouchPoints > 0
      if event_type == 'scroll'
        base_event_type = 'pinch'

    gestures = @plot.toolbar.gestures
    active_tool = gestures[base_event_type].active

    if active_tool?
      @_trigger_event(event_type, active_tool, e)

  _trigger_event: (event_type, active_tool, e)->
    if active_tool.active == true
      if event_type == 'scroll'
        e.preventDefault()
        e.stopPropagation()
      @trigger("#{event_type}:#{active_tool.id}", e)

  _bokify_hammer: (e) ->

    if e.pointerType == 'mouse'
      x = e.srcEvent.pageX
      y = e.srcEvent.pageY
    else
      x = e.pointers[0].pageX
      y = e.pointers[0].pageY
    offset = $(e.target).offset()
    left = offset.left ? 0
    top = offset.top ? 0
    e.bokeh = {
      sx: x - left
      sy: y - top
    }
    xmapper = @plot.plot_canvas.frame.x_mappers['default']
    ymapper = @plot.plot_canvas.frame.y_mappers['default']
    e.bokeh["x"] = xmapper.map_to_target(e.bokeh.sx)
    e.bokeh["y"] = ymapper.map_to_target(e.bokeh.sx)

  _bokify_jq: (e) ->
    offset = $(e.currentTarget).offset()
    left = offset.left ? 0
    top = offset.top ? 0
    e.bokeh = {
      sx: e.pageX - left
      sy: e.pageY - top
    }

  _tap: (e) ->
    @_bokify_hammer(e)
    @_trigger('tap', e)
    @on_tap?.execute(@, e)

  _doubletap: (e) ->
    # NOTE: doubletap event triggered unconditionally
    @_bokify_hammer(e)
    @trigger('doubletap', e)
    @on_doubletap?.execute(@, e)

  _press: (e) ->
    @_bokify_hammer(e)
    @_trigger('press', e)
    @on_press?.execute(@, e)

  _pan_start: (e) ->
    @_bokify_hammer(e)
    # back out delta to get original center point
    e.bokeh.sx -= e.deltaX
    e.bokeh.sy -= e.deltaY
    @_trigger('pan:start', e)
    @on_pan_start?.execute(@, e)

  _pan: (e) ->
    @_bokify_hammer(e)
    @_trigger('pan', e)
    @on_pan?.execute(@, e)

  _pan_end: (e) ->
    @_bokify_hammer(e)
    @_trigger('pan:end', e)
    @on_pan_end?.execute(@, e)

  _pinch_start: (e) ->
    @_bokify_hammer(e)
    @_trigger('pinch:start', e)
    @on_pinch_start?.execute(@, e)

  _pinch: (e) ->
    @_bokify_hammer(e)
    @_trigger('pinch', e)
    @on_pinch?.execute(@, e)

  _pinch_end: (e) ->
    @_bokify_hammer(e)
    @_trigger('pinch:end', e)
    @on_pinch_end?.execute(@, e)

  _rotate_start: (e) ->
    @_bokify_hammer(e)
    @_trigger('rotate:start', e)
    @on_rotate_start?.execute(@, e)

  _rotate: (e) ->
    @_bokify_hammer(e)
    @_trigger('rotate', e)
    @on_rotate?.execute(@, e)

  _rotate_end: (e) ->
    @_bokify_hammer(e)
    @_trigger('rotate:end', e)
    @on_rotate_end?.execute(@, e)

  _mouse_enter: (e) ->
    # NOTE: move:enter event triggered unconditionally
    @_bokify_jq(e)
    @trigger('move:enter', e)
    @on_mouse_enter?.execute(@, e)

  _mouse_move: (e) ->
    # NOTE: move event triggered unconditionally
    @_bokify_jq(e)
    @trigger('move', e)
    @on_mouse_move?.execute(@, e)

  _mouse_exit: (e) ->
    # NOTE: move:exit event triggered unconditionally
    @_bokify_jq(e)
    @trigger('move:exit', e)
    @on_mouse_exit?.execute(@, e)

  _mouse_wheel: (e, delta) ->
    @_bokify_jq(e)
    e.bokeh.delta = delta
    @_trigger('scroll', e)
    @on_mouse_wheel?.execute(@, e)

  _key_down: (e) ->
    # NOTE: keydown event triggered unconditionally
    @trigger('keydown', e)
    @on_key_down?.execute(@, e)

  _key_up: (e) ->
    # NOTE: keyup event triggered unconditionally
    @trigger('keyup', e)
    @on_key_up?.execute(@, e)

module.exports = {
  Model: UIEvents
}