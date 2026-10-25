extends Node2D
## Development scene: drive the 2012 baseline car on the test circuit with keyboard,
## gamepad or touch (mouse emulates touch here).
## F1 toggles TC+ABS, F2 cycles compound (new tyres), F3 cycles rain (water 0 / 0.3 / 0.7),
## F4 shows/hides the touch controls (shown by default only on touch screens).

const WATER_STEPS := [0.0, 0.3, 0.7]
const COMPOUNDS := [&"supersoft", &"soft", &"medium", &"hard", &"intermediate", &"wet"]

var track: TrackData
var env: TrackEnvironment
var controller: CarController
var car_view: CarRenderer
var camera: ChaseCamera
var touch: TouchControls
var overlay: DebugOverlay
var mapper := InputMapper.new()
var _water_index := 0
var _compound_index := 2
var _last_s := 0.0


func _ready() -> void:
	InputMapper.ensure_actions()
	track = TestTrackBuilder.build()
	add_child(TrackMeshBuilder.build(track))
	env = TrackEnvironment.on(track)

	var spec := CarSpec.baseline_2012()
	var state := CarState.create(spec, COMPOUNDS[_compound_index], 90.0)
	# Start at the beginning of the main straight (the last points are the closing corner).
	state.position = track.points[2]
	state.heading = (track.points[3] - track.points[2]).angle()

	controller = CarController.new()
	controller.name = "PlayerCar"
	controller.setup(spec, state, env)
	controller.input_source = func(s: CarState, dt: float) -> DriverInput: return mapper.read(s, dt, touch)
	var backends: Array[HapticsBackend] = [WebHaptics.new(), JoypadHaptics.new()]
	controller.haptics = HapticsDirector.new(backends)
	add_child(controller)

	car_view = CarRenderer.new()
	car_view.controller = controller
	add_child(car_view)

	camera = ChaseCamera.new()
	camera.follow = car_view
	add_child(camera)
	camera.make_current()

	var ui := CanvasLayer.new()
	add_child(ui)
	touch = TouchControls.new()
	touch.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Mouse-to-touch emulation makes every desktop report a touchscreen, so ask for a real device.
	touch.visible = OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")
	ui.add_child(touch)
	overlay = DebugOverlay.new()
	overlay.controller = controller
	ui.add_child(overlay)
	_update_extra()

	car_view._process(0.0)
	camera.snap()
	_last_s = env.geometry.project(state.position).s
	_maybe_capture()


## Dev aid: `-- --capture=<png> [--capture-seconds=N]` drives flat out with a gentle
## line-following steer, saves a screenshot after N seconds and quits.
func _maybe_capture() -> void:
	var path := ""
	var seconds := 3.0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):
			path = arg.trim_prefix("--capture=")
		elif arg.begins_with("--capture-seconds="):
			seconds = float(arg.trim_prefix("--capture-seconds="))
	if path.is_empty():
		return
	controller.input_source = func(s: CarState, _dt: float) -> DriverInput:
		var p := env.geometry.project(s.position + s.forward() * 25.0)
		var i := DriverInput.new()
		i.throttle = 0.85
		i.steer = clampf(-p.lateral * 0.08 + angle_difference(s.heading, p.tangent.angle()) * 1.5, -1.0, 1.0)
		return i
	await get_tree().create_timer(seconds).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()


func _physics_process(_delta: float) -> void:
	var s := env.geometry.project(controller.state.position).s
	if s < _last_s - track.length() * 0.5:
		controller.state.powertrain.reset_kers_lap()  # crossed the line
	_last_s = s


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.physical_keycode:
		KEY_F1:
			var on := not controller.assists.traction_control
			controller.assists.traction_control = on
			controller.assists.abs = on
		KEY_F2:
			_compound_index = (_compound_index + 1) % COMPOUNDS.size()
			var id: StringName = COMPOUNDS[_compound_index]
			var temp := 60.0 if TyreCompounds.get_compound(id).is_wet_tyre else 90.0
			for w in controller.state.wheels:
				w.tyre = TyreState.fresh(id, temp)
		KEY_F3:
			_water_index = (_water_index + 1) % WATER_STEPS.size()
			env.water = WATER_STEPS[_water_index]
		KEY_F4:
			touch.visible = not touch.visible
		_:
			return
	_update_extra()


func _update_extra() -> void:
	overlay.extra = "agua %.1f   ayudas %s   [F1 ayudas · F2 compuesto · F3 lluvia · F4 táctil]" % [
		env.water, "SÍ" if controller.assists.traction_control else "no"]
