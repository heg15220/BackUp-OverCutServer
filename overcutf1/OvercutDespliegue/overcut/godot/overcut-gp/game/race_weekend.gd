class_name RaceWeekend
extends Node3D
## A Grand Prix weekend in 3D: qualifying (Q1/Q2/Q3 driven by the player against the clock)
## and the race (RaceSession: start lights, 24 cars, pit stops, safety car, retirements),
## with the broadcast HUD, touch controls, haptics and the overhead camera.
## Dev flags (after `--`): --capture=<png> --capture-seconds=N --stage=race|quali.

enum Stage { QUALI, QUALI_BREAK, RACE, DONE }

const PIT_COMPOUNDS := [&"soft", &"medium"]
const FAST_FORWARD_TICKS := 900
const RESULTS_DELAY := 3.0
## "Esperar" in the garage: qualifying runs this many times faster while the player waits.
const GARAGE_WAIT_SPEED := 10

var app: App
var gp: Dictionary
var track_path := ""
var model: SeasonModel
var champ: Championship
var track: LoadedTrack
var stage := Stage.QUALI
var quali: QualiSession
var session: RaceSession
var visuals := {}  ## code -> {visual: CarVisual, tag: Label3D, prev_pos, prev_heading, state}
var camera: OverheadCamera
var touch: TouchControls
var hud: RaceHud
var overlay: Control
var mapper := InputMapper.new()
var haptics: HapticsDirector
var clock := SimClock.new()
var assists := AssistConfig.new()
var player_code := ""
var _last_raw := DriverInput.new()
var _fast_forward := false
var _finished_for := 0.0
var _now := 0.0
var _capture_path := ""
var _capture_seconds := 4.0
var _ai_player: AiDriver
var _garage_wait := false


func _ready() -> void:
	model = app.model
	champ = app.champ
	player_code = champ.player_code
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):
			_capture_path = arg.trim_prefix("--capture=")
		elif arg.begins_with("--capture-seconds="):
			_capture_seconds = float(arg.trim_prefix("--capture-seconds="))
	assists.traction_control = champ.assists.get("traction_control", false)
	assists.abs = champ.assists.get("abs", false)
	assists.auto_gearbox = champ.assists.get("auto_gearbox", true)
	assists.stability_control = champ.assists.get("stability_control", false)
	mapper.assists = assists
	track = TrackLoader.load_track(track_path)
	add_child(TrackWorldBuilder.new(track).build_world())
	TrackLighting.add_to(self)
	_spawn_visuals()
	_build_ui()
	var backends: Array[HapticsBackend] = [WebHaptics.new(), JoypadHaptics.new()]
	haptics = HapticsDirector.new(backends)
	if "--stage=race" in OS.get_cmdline_user_args():
		_start_race(Qualifying.simulate(track, model, gp["id"], champ.level, _seed(), player_code).grid_codes(player_code))
	else:
		_start_quali()
	if _capture_path != "":
		_run_capture()


func _seed() -> int:
	return absi(hash(gp["id"])) % 100000 + champ.round * 7919


# --- scene ----------------------------------------------------------------------------

func _spawn_visuals() -> void:
	for d in model.starters():
		var team := model.team(d["team"])
		var visual := CarVisual.new()
		visual.setup(team, d["helmet"])
		add_child(visual)
		var tag := Label3D.new()
		tag.text = d["code"]
		tag.font_size = 72
		tag.outline_size = 14
		tag.pixel_size = 0.012
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.no_depth_test = true
		tag.modulate = Color(team["colors"]["primary"]).lightened(0.35) if d["code"] != player_code else Color("#ffd400")
		add_child(tag)
		visuals[d["code"]] = {"visual": visual, "tag": tag, "prev_pos": Vector2.ZERO, "prev_heading": 0.0, "state": null}


func _bind(code: String, state: CarState) -> void:
	var v: Dictionary = visuals[code]
	v["state"] = state
	v["prev_pos"] = state.position
	v["prev_heading"] = state.heading
	v["visual"].visible = true
	v["tag"].visible = true


func _hide_all() -> void:
	for code in visuals:
		visuals[code]["visual"].visible = false
		visuals[code]["tag"].visible = false
		visuals[code]["state"] = null


func _build_ui() -> void:
	camera = OverheadCamera.new()
	camera.height_scale = champ.camera_zoom
	add_child(camera)
	camera.make_current()
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.theme = UiKit.theme()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	touch = TouchControls.new()
	touch.set_anchors_preset(Control.PRESET_FULL_RECT)
	touch.visible = OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")
	root.add_child(touch)
	hud = RaceHud.new()
	hud.touch_buttons = touch.visible
	root.add_child(hud)
	hud.set_track(track.data.points)
	hud.pit_toggled.connect(_toggle_pit)
	hud.compound_cycled.connect(_cycle_compound)
	hud.pause_pressed.connect(_pause)
	hud.skip_pressed.connect(_skip)
	overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(overlay)


func _follow(code: String) -> void:
	camera.target = visuals[code]["visual"]
	camera.target_state = visuals[code]["state"]
	camera.snap()


func _player_input(s: CarState, dt: float) -> DriverInput:
	if _ai_player != null:
		_last_raw = _ai_player.drive(s, dt)
	else:
		_last_raw = mapper.read(s, dt, touch)
	return _last_raw


# --- qualifying -----------------------------------------------------------------------

func _start_quali() -> void:
	stage = Stage.QUALI
	quali = QualiSession.new()
	quali.setup(track, model, gp["id"], champ.level, player_code, _seed())
	quali.assists = assists
	quali.player_input = _player_input
	_show_quali_car()
	_toast("%s · %s\nEstás en el box: pulsa «Salir a pista» (P) cuando quieras" % [app.gp_name(gp), QualiSession.SESSION_NAMES[0]])


func _show_quali_car() -> void:
	_hide_all()
	_garage_wait = false
	for c in quali.cars:
		_bind(c.code, c.state)
	_follow(player_code)


func _quali_session_over() -> void:
	stage = Stage.QUALI_BREAK
	_clear_overlay()
	var table := quali.live_table()
	var s := quali.session
	var title := "%s terminada" % QualiSession.SESSION_NAMES[s]
	var verdict := ""
	var button := ""
	var mine := quali.player_position()
	if quali.phase == QualiSession.Phase.BETWEEN:
		verdict = "P%d · pasas a %s" % [mine, QualiSession.SESSION_NAMES[s + 1]]
		button = "Salir a %s" % QualiSession.SESSION_NAMES[s + 1]
	else:
		var result := quali.final_result()
		var grid := result.grid_codes(player_code)
		var slot := grid.find(player_code) + 1
		verdict = ("Eliminado en %s · " % QualiSession.SESSION_NAMES[quali.eliminated_in] if quali.eliminated_in >= 0 else "") + "Sales P%d" % slot
		if slot == 1:
			verdict = "¡POLE POSITION!"
		button = "Ir a la parrilla"
	var rows := []
	for k in mini(table.size(), 24):
		var r: Dictionary = table[k]
		var t: float = r["time"]
		rows.append([str(k + 1), Color(model.team(r["team"])["colors"]["primary"]), r["code"] + "  " + model.driver(r["code"])["last_name"], RaceFormat.lap_time(t), r["code"] == player_code])
	_panel(title, verdict, rows, button, func():
		_clear_overlay()
		if quali.phase == QualiSession.Phase.BETWEEN:
			quali.start_next()
			stage = Stage.QUALI
			_show_quali_car()
		else:
			_start_race(quali.final_result().grid_codes(player_code)))


# --- race -----------------------------------------------------------------------------

func _start_race(grid_codes: Array) -> void:
	stage = Stage.RACE
	_hide_all()
	session = RaceSession.new()
	var laps := RaceRules.race_laps(int(gp["laps"]), champ.length)
	session.setup(track, model, gp["id"], laps, RaceRules.mandatory_stop(champ.length), champ.level, player_code, _seed(), grid_codes)
	session.player_input = _player_input
	session.set_player_assists(assists)
	for e in session.entries:
		_bind(e.code, e.state)
	_follow(player_code)
	var p := session.player_entry()
	_toast("Carrera a %d vueltas · sales P%d%s" % [laps, p.grid_position, " · parada obligatoria" if session.mandatory else ""])


func _toggle_pit() -> void:
	if stage == Stage.QUALI:
		if quali.player.run == QualiCar.Run.GARAGE:
			quali.leave_garage()
		else:
			quali.request_pit()
		return
	if session == null:
		return
	var p := session.player_entry()
	p.pit_requested = not p.pit_requested


func _cycle_compound() -> void:
	if stage == Stage.QUALI:
		_garage_wait = not _garage_wait and quali.player.run == QualiCar.Run.GARAGE
		return
	if session == null:
		return
	var p := session.player_entry()
	var k := PIT_COMPOUNDS.find(p.pit_compound)
	p.pit_compound = PIT_COMPOUNDS[(k + 1) % PIT_COMPOUNDS.size()]


func _skip() -> void:
	match stage:
		Stage.QUALI:
			quali.end_session()
		Stage.RACE:
			_fast_forward = true


func _race_over() -> void:
	stage = Stage.DONE
	var order := []
	var rows := []
	var winner_time := 0.0
	var winner_laps := 0
	for e in session.classification():
		var row := {"code": e.code, "status": "", "gap": ""}
		if e.status == RaceEntry.Status.FINISHED:
			if order.is_empty():
				winner_time = e.finish_time
				winner_laps = e.laps_done
				row["gap"] = RaceFormat.lap_time(e.finish_time - session.lights_out_at)
			else:
				row["gap"] = RaceFormat.gap(e.finish_time - winner_time, winner_laps - e.laps_done)
			if e.penalty_s > 0.0:
				row["gap"] += " (+%ds)" % int(e.penalty_s)
			order.append(e.code)
		else:
			row["status"] = e.retire_reason if e.retire_reason != "" else "Abandono"
		rows.append(row)
	if _capture_path == "":
		app.weekend_finished(order, session.fastest_lap_code, rows)


# --- loop -----------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	var ticks := clock.advance(delta)
	if stage == Stage.QUALI and _garage_wait:
		if quali.player.run == QualiCar.Run.GARAGE:
			ticks *= GARAGE_WAIT_SPEED
		else:
			_garage_wait = false
	for i in ticks:
		_tick()
	if _fast_forward and stage == Stage.RACE:
		for i in FAST_FORWARD_TICKS:
			if session.phase == RaceSession.Phase.FINISHED:
				break
			_tick()


func _tick() -> void:
	match stage:
		Stage.QUALI:
			_remember_poses()
			quali.step(SimClock.TICK)
			haptics.update(quali.state, quali.last_input, SimClock.TICK)
			if quali.phase != QualiSession.Phase.RUNNING:
				_quali_session_over()
		Stage.RACE:
			_remember_poses()
			session.step(SimClock.TICK)
			var p := session.player_entry()
			if p.status == RaceEntry.Status.RUNNING and not _fast_forward:
				haptics.update(p.state, _last_raw, SimClock.TICK)


func _remember_poses() -> void:
	for code in visuals:
		var v: Dictionary = visuals[code]
		if v["state"] != null:
			v["prev_pos"] = v["state"].position
			v["prev_heading"] = v["state"].heading


func _process(delta: float) -> void:
	_now += delta
	var alpha := Engine.get_physics_interpolation_fraction()
	for code in visuals:
		var v: Dictionary = visuals[code]
		var st: CarState = v["state"]
		if st == null:
			continue
		var pos: Vector2 = v["prev_pos"].lerp(st.position, alpha)
		v["visual"].sync(st, pos, lerp_angle(v["prev_heading"], st.heading, alpha))
		v["tag"].position = Vector3(pos.x, st.height + 2.6, pos.y)
	match stage:
		Stage.QUALI, Stage.QUALI_BREAK:
			hud.show_quali(quali, _now, _garage_wait)
			for c in quali.cars:
				visuals[c.code]["tag"].visible = c.out_of_garage()
			hud.set_skip(stage == Stage.QUALI, "Simular resto de %s" % QualiSession.SESSION_NAMES[quali.session])
		Stage.RACE, Stage.DONE:
			var p := session.player_entry()
			hud.show_race(session, p, _now)
			var env := session._env()
			hud.set_weather(env.air_c, env.track_c, env.water)
			var out := p.status != RaceEntry.Status.RUNNING and p.status != RaceEntry.Status.PIT
			hud.set_skip(stage == Stage.RACE and out and not _fast_forward, "Avance rápido hasta el final")
			for e in session.entries:
				visuals[e.code]["tag"].visible = e.status != RaceEntry.Status.RETIRED
			if stage == Stage.RACE and session.phase == RaceSession.Phase.FINISHED:
				_finished_for += delta
				if _finished_for > RESULTS_DELAY or _fast_forward:
					_race_over()
	if stage != Stage.RACE and stage != Stage.DONE:
		hud.set_weather(quali.env.air_c, quali.env.track_c, quali.env.water)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE:
				_pause()
			KEY_P:
				_toggle_pit()
			KEY_C:
				_cycle_compound()
	elif event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_START:
			_pause()
		elif event.button_index == JOY_BUTTON_B:
			_toggle_pit()
		elif event.button_index == JOY_BUTTON_X:
			_cycle_compound()


# --- overlays -------------------------------------------------------------------------

func _pause() -> void:
	if get_tree().paused or stage == Stage.DONE:
		return
	get_tree().paused = true
	touch.release_all()
	var buttons := [["Continuar", func(): _resume()]]
	if stage == Stage.QUALI:
		buttons.append(["Simular resto de la sesión", func():
			_resume()
			quali.end_session()])
	if stage == Stage.RACE and session.player_entry().status == RaceEntry.Status.RUNNING:
		buttons.append(["Retirarse de la carrera", func():
			_resume()
			session.player_entry().retire("Retirado", session.time)
			_fast_forward = true])
	buttons.append(["Salir al mundial (sin puntuar)", func():
		_resume()
		app.weekend_abandoned()])
	var p := UiKit.panel("Pausa")
	var v: VBoxContainer = p[1]
	for b in buttons:
		v.add_child(UiKit.button(b[0], b[1]))
	v.add_child(UiKit.label("Ayudas a la conducción", 18, UiKit.MUTED))
	for a in SettingsScreen.AIDS:
		var t := CheckButton.new()
		t.text = a[1]
		t.button_pressed = bool(assists.get(a[0]))
		t.custom_minimum_size = Vector2(0, 48)
		t.toggled.connect(func(on): set_aid(a[0], on))
		v.add_child(t)
	_center(p[0], 460)


## An aid switched from the pause menu: on the car at once, and saved for the next sessions.
func set_aid(aid: String, on: bool) -> void:
	assists.set(aid, on)
	champ.assists[aid] = on
	champ.save(app.save_path)


func _resume() -> void:
	get_tree().paused = false
	_clear_overlay()


func _clear_overlay() -> void:
	for c in overlay.get_children():
		c.queue_free()


func _center(panel: Control, width: float) -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var vp := get_viewport().get_visible_rect().size
	panel.custom_minimum_size = Vector2(minf(width, vp.x - 32), 0)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(minf(width, vp.x - 32), minf(vp.y - 40, 900))
	scroll.add_child(panel)
	center.add_child(scroll)


func _panel(title: String, verdict: String, rows: Array, button: String, on_press: Callable) -> void:
	var p := UiKit.panel(title)
	var v: VBoxContainer = p[1]
	v.add_child(UiKit.label(verdict, 28, Color("#ffd400")))
	v.add_child(UiKit.button(button, on_press, 64))
	for r in rows:
		v.add_child(UiKit.table_row(r[0], r[1], r[2], r[3], r[4]))
	_center(p[0], 560)


func _toast(text: String) -> void:
	var l := UiKit.label(text, 22, Color.WHITE)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	# Full width minus a 20 px margin each side, so it follows the window when it resizes.
	l.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	l.offset_left = 20
	l.offset_right = -20
	l.offset_top = 210  # below the HUD header, skip button and session message
	overlay.add_child(l)
	var tw := create_tween()
	tw.tween_interval(4.0)
	tw.tween_property(l, "modulate:a", 0.0, 0.8)
	tw.tween_callback(l.queue_free)


# --- dev capture ----------------------------------------------------------------------

## Lets the AI drive the player's car and saves a screenshot (headed runs only).
func _run_capture() -> void:
	var spec := quali.spec if quali != null else session.player_entry().spec
	_ai_player = AiDriver.new(track, SpeedProfile.build(track, spec, &"soft"), AiSkill.level(AiSkill.LEGEND), 3)
	if quali != null and stage == Stage.QUALI:
		quali.leave_garage()
	assists.traction_control = true
	assists.abs = true
	assists.stability_control = true
	await get_tree().create_timer(_capture_seconds).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_capture_path)
	get_tree().quit()
