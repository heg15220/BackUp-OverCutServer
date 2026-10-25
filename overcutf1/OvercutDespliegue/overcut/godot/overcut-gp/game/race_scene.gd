class_name RaceScene
extends Node3D
## A Grand Prix weekend scene: Albert Park in 3D, the 24 cars of 2012 on the real grid,
## the player's car driven with keyboard, gamepad or touch, and the overhead camera.
## Dev flags: `-- --capture=<png> [--capture-seconds=N] [--driver=CODE]`.

const TRACK_PATH := "res://data/tracks/melbourne_2012.json"
const SEASON_PATH := "res://data/seasons/2012.json"

@export var player_code := "HAM"

var track: LoadedTrack
var season: Dictionary
var env: TrackEnvironment
var world_builder: TrackWorldBuilder
var cars: Array[Dictionary] = []  ## {driver, team, state, controller, visual, tag}
var player: Dictionary
var camera: OverheadCamera
var touch: TouchControls
var mapper := InputMapper.new()
var hud_label: Label
var _camera_height_scale := 1.0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--driver="):
			player_code = arg.trim_prefix("--driver=")
		elif arg.begins_with("--camera-height="):
			_camera_height_scale = float(arg.trim_prefix("--camera-height="))
	InputMapper.ensure_actions()
	track = TrackLoader.load_track(TRACK_PATH)
	season = JSON.parse_string(FileAccess.get_file_as_string(SEASON_PATH))
	env = TrackEnvironment.on(track.data)
	world_builder = TrackWorldBuilder.new(track)
	add_child(world_builder.build_world())
	_add_sky_and_sun()
	_spawn_cars()
	_add_camera_and_ui()
	_maybe_capture()


func _add_sky_and_sun() -> void:
	TrackLighting.add_to(self)


func _spawn_cars() -> void:
	var teams := {}
	for t in season["teams"]:
		teams[t["id"]] = t
	var real_q: Array = season["real_results"]["australia"]["qualifying"]
	var spec := CarSpec.baseline_2012()
	for k in real_q.size():
		var q: Dictionary = real_q[k]
		var driver := _driver(q["code"])
		var slot := track.grid[mini(k, track.grid.size() - 1)]
		var state := CarState.create(spec, &"soft", 85.0)
		state.position = slot.position
		state.heading = slot.heading
		state.height = track.data.heights[slot.index]
		var controller := CarController.new()
		controller.setup(spec, state, env)
		add_child(controller)
		var visual := CarVisual.new()
		visual.setup(teams[driver["team"]], driver["helmet"])
		add_child(visual)
		visual.sync(state, state.position, state.heading)
		var tag := Label3D.new()
		tag.text = driver["code"]
		tag.font_size = 72
		tag.outline_size = 14
		tag.pixel_size = 0.012
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.no_depth_test = true
		tag.modulate = Color(teams[driver["team"]]["colors"]["primary"]).lightened(0.35)
		add_child(tag)
		var car := {"driver": driver, "team": teams[driver["team"]], "state": state, "controller": controller, "visual": visual, "tag": tag}
		cars.append(car)
		if driver["code"] == player_code:
			player = car
	if player.is_empty():
		player = cars[0]
	var backends: Array[HapticsBackend] = [WebHaptics.new(), JoypadHaptics.new()]
	player["controller"].haptics = HapticsDirector.new(backends)
	player["controller"].input_source = func(s: CarState, dt: float) -> DriverInput: return mapper.read(s, dt, touch)


func _driver(code: String) -> Dictionary:
	for d in season["drivers"]:
		if d["code"] == code and d["starter"]:
			return d
	return {}


func _add_camera_and_ui() -> void:
	camera = OverheadCamera.new()
	camera.target = player["visual"]
	camera.target_state = player["state"]
	camera.height_scale = _camera_height_scale
	add_child(camera)
	camera.make_current()
	camera.snap()
	var ui := CanvasLayer.new()
	add_child(ui)
	touch = TouchControls.new()
	touch.set_anchors_preset(Control.PRESET_FULL_RECT)
	touch.visible = OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")
	ui.add_child(touch)
	hud_label = Label.new()
	hud_label.position = Vector2(16, 12)
	hud_label.add_theme_font_size_override("font_size", 18)
	hud_label.add_theme_color_override("font_color", Color.WHITE)
	hud_label.add_theme_color_override("font_outline_color", Color.BLACK)
	hud_label.add_theme_constant_override("outline_size", 6)
	ui.add_child(hud_label)


func _process(_delta: float) -> void:
	var alpha := Engine.get_physics_interpolation_fraction()
	for car in cars:
		var c: CarController = car["controller"]
		var pos := c.interpolated_position(alpha)
		car["visual"].sync(car["state"], pos, c.interpolated_heading(alpha))
		car["tag"].position = Vector3(pos.x, car["state"].height + 2.6, pos.y)
	var s: CarState = player["state"]
	hud_label.text = "%s · %s   %d km/h   marcha %d" % [player["driver"]["code"], player["team"]["name"], roundi(Units.kmh(s.speed())), s.powertrain.gear]


## Dev aid: drives the player's car along the racing line and saves a screenshot.
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
	var geo := env.geometry
	player["controller"].input_source = func(s: CarState, _dt: float) -> DriverInput:
		var p := geo.project_hinted(s.position + s.forward() * 18.0, maxi(s.track_index, 0))
		var target := track.racing_line[p.index] if not track.racing_line.is_empty() else 0.0
		var i := DriverInput.new()
		i.throttle = 0.7
		i.steer = clampf(-(p.lateral - target) * 0.1 + angle_difference(s.heading, p.tangent.angle()) * 1.6, -1.0, 1.0)
		return i
	await get_tree().create_timer(seconds).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()
