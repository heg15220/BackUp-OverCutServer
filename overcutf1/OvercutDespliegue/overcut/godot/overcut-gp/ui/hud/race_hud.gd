class_name RaceHud
extends Control
## Broadcast-style HUD of the 2004–2017 era: timing tower, lap counter, start lights,
## weather and track panel, minimap, the relative (car ahead and behind), the driver's
## dashboard (speed, gear, revs, KERS, DRS, tyres) and race control messages.
## The weekend scene fills it every frame through show_race() / show_quali().

signal pit_toggled
signal compound_cycled
signal pause_pressed
signal skip_pressed

const BOX := Color(0.02, 0.02, 0.03, 0.78)
const BOX_LIGHT := Color(0.12, 0.12, 0.15, 0.85)
const PURPLE := Color("#b36bff")
const YELLOW := Color("#ffd400")
const ROW_H := 26.0
const MAX_ROWS := 24

var tower: VBoxContainer
var tower_rows: Array = []  ## [{root, pos, bar, code, value}]
var header: Label
var subheader: Label
var weather: Label
var minimap: Minimap
var relative: VBoxContainer
var relative_rows: Array = []
var dash_speed: Label
var dash_gear: Label
var dash_rpm: ProgressBar
var dash_kers: ProgressBar
var dash_drs: Label
var dash_tyre: Label
var dash_lap: Label
var message: Label
var lights: HBoxContainer
var light_dots: Array[Panel] = []
var pit_button: Button
var compound_button: Button
var action_row: HBoxContainer
var skip_button: Button
var touch_row: HBoxContainer
## Hold buttons for KERS and DRS on touch screens.
var touch_buttons := false
var _message_until := 0.0
var _last_event_count := 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_tower()
	_build_header()
	_build_right_column()
	_build_dashboard()
	_build_lights()
	_build_message()
	_build_actions()
	resized.connect(_layout)
	_layout()


# --- construction -------------------------------------------------------------------

static func _box(color := BOX) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(4)
	s.content_margin_left = 8
	s.content_margin_right = 8
	s.content_margin_top = 4
	s.content_margin_bottom = 4
	return s


static func _text(size: int, color := Color.WHITE, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 4)
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _panel(child: Control, color := BOX) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _box(color))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(child)
	add_child(p)
	return p


func _build_tower() -> void:
	tower = VBoxContainer.new()
	tower.add_theme_constant_override("separation", 1)
	tower.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tower.position = Vector2(12, 12)
	add_child(tower)
	for k in MAX_ROWS:
		var root := PanelContainer.new()
		var sb := _box()
		sb.content_margin_top = 1
		sb.content_margin_bottom = 1
		sb.content_margin_left = 0
		sb.set_corner_radius_all(0)
		root.add_theme_stylebox_override("panel", sb)
		root.custom_minimum_size = Vector2(196, ROW_H)
		root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 6)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(h)
		var pos := _text(17, Color.BLACK, HORIZONTAL_ALIGNMENT_CENTER)
		pos.remove_theme_constant_override("outline_size")
		pos.custom_minimum_size = Vector2(28, 0)
		var pos_bg := PanelContainer.new()
		var pb := StyleBoxFlat.new()
		pb.bg_color = Color(0.95, 0.95, 0.97)
		pos_bg.add_theme_stylebox_override("panel", pb)
		pos_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pos_bg.add_child(pos)
		h.add_child(pos_bg)
		var bar := ColorRect.new()
		bar.custom_minimum_size = Vector2(4, 0)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(bar)
		var code := _text(17)
		code.custom_minimum_size = Vector2(46, 0)
		h.add_child(code)
		var value := _text(16, Color(0.85, 0.87, 0.9), HORIZONTAL_ALIGNMENT_RIGHT)
		value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(value)
		tower.add_child(root)
		tower_rows.append({"root": root, "pos": pos, "bar": bar, "code": code, "value": value, "style": sb})


func _build_header() -> void:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header = _text(24, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	subheader = _text(15, Color(0.8, 0.82, 0.86), HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(header)
	v.add_child(subheader)
	var p := _panel(v)
	p.name = "Header"


func _build_right_column() -> void:
	weather = _text(15)
	_panel(weather).name = "Weather"
	minimap = Minimap.new()
	minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel(minimap, Color(0.02, 0.02, 0.03, 0.55)).name = "Map"
	relative = VBoxContainer.new()
	relative.add_theme_constant_override("separation", 2)
	relative.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for k in 3:
		var l := _text(16)
		relative.add_child(l)
		relative_rows.append(l)
	_panel(relative).name = "Relative"


func _build_dashboard() -> void:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_constant_override("separation", 14)
	dash_gear = _text(40, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	dash_gear.custom_minimum_size = Vector2(36, 0)
	top.add_child(dash_gear)
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 0)
	sv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dash_speed = _text(28)
	sv.add_child(dash_speed)
	dash_lap = _text(14, Color(0.8, 0.82, 0.86))
	sv.add_child(dash_lap)
	top.add_child(sv)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 0)
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dash_drs = _text(16, Color(0.6, 0.6, 0.6))
	right.add_child(dash_drs)
	dash_tyre = _text(14)
	right.add_child(dash_tyre)
	top.add_child(right)
	v.add_child(top)
	dash_rpm = _bar(Color("#e10600"))
	v.add_child(dash_rpm)
	dash_kers = _bar(Color("#2fd1ff"))
	v.add_child(dash_kers)
	var p := _panel(v)
	p.name = "Dash"


func _bar(color: Color) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.custom_minimum_size = Vector2(250, 7)
	b.min_value = 0.0
	b.max_value = 1.0
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(1, 1, 1, 0.12)
	var fg := StyleBoxFlat.new()
	fg.bg_color = color
	b.add_theme_stylebox_override("background", bg)
	b.add_theme_stylebox_override("fill", fg)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


func _build_lights() -> void:
	lights = HBoxContainer.new()
	lights.add_theme_constant_override("separation", 10)
	lights.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for k in 5:
		var d := Panel.new()
		d.custom_minimum_size = Vector2(46, 46)
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lights.add_child(d)
		light_dots.append(d)
	var p := _panel(lights)
	p.name = "Lights"
	p.visible = false


func _build_message() -> void:
	message = _text(20, YELLOW, HORIZONTAL_ALIGNMENT_CENTER)
	var p := _panel(message)
	p.name = "Message"
	p.visible = false


func _build_actions() -> void:
	action_row = HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 8)
	add_child(action_row)
	compound_button = _action("Neumático: —", func(): compound_cycled.emit())
	pit_button = _action("BOXES", func(): pit_toggled.emit())
	skip_button = Button.new()
	skip_button.focus_mode = Control.FOCUS_NONE
	skip_button.custom_minimum_size = Vector2(0, 52)
	skip_button.add_theme_font_size_override("font_size", 17)
	skip_button.add_theme_stylebox_override("normal", _box(BOX_LIGHT))
	skip_button.add_theme_stylebox_override("hover", _box(Color(0.2, 0.2, 0.25, 0.9)))
	skip_button.pressed.connect(func(): skip_pressed.emit())
	skip_button.name = "Skip"
	add_child(skip_button)
	var pause := Button.new()
	pause.text = "II"
	pause.name = "Pause"
	pause.focus_mode = Control.FOCUS_NONE
	pause.custom_minimum_size = Vector2(56, 52)
	pause.add_theme_stylebox_override("normal", _box(BOX_LIGHT))
	pause.pressed.connect(func(): pause_pressed.emit())
	add_child(pause)
	touch_row = HBoxContainer.new()
	touch_row.add_theme_constant_override("separation", 8)
	add_child(touch_row)
	for a in [[&"kers", "KERS"], [&"drs", "DRS"]]:
		var b := Button.new()
		b.text = a[1]
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(84, 60)
		b.add_theme_stylebox_override("normal", _box(BOX_LIGHT))
		b.add_theme_stylebox_override("pressed", _box(UiKit.ACCENT))
		b.button_down.connect(func(): Input.action_press(a[0]))
		b.button_up.connect(func(): Input.action_release(a[0]))
		touch_row.add_child(b)


func _action(text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 52)
	b.add_theme_font_size_override("font_size", 17)
	b.add_theme_stylebox_override("normal", _box(BOX_LIGHT))
	b.add_theme_stylebox_override("hover", _box(Color(0.2, 0.2, 0.25, 0.9)))
	b.add_theme_stylebox_override("pressed", _box(UiKit.ACCENT))
	b.pressed.connect(on_press)
	action_row.add_child(b)
	return b


# --- layout ---------------------------------------------------------------------------

func is_portrait() -> bool:
	return size.y > size.x


func visible_rows() -> int:
	var avail := size.y * (0.42 if is_portrait() else 0.62)
	return clampi(int(avail / (ROW_H + 1)), 5, MAX_ROWS)


func _layout() -> void:
	if not is_inside_tree():
		return
	var w := size.x
	var h := size.y
	var portrait := is_portrait()
	var hdr: Control = get_node("Header")
	hdr.position = Vector2((w - hdr.size.x) * 0.5, 10)
	var wth: Control = get_node("Weather")
	var map: Control = get_node("Map")
	var rel: Control = get_node("Relative")
	var map_side := clampf(minf(w, h) * (0.30 if portrait else 0.26), 140, 260)
	minimap.custom_minimum_size = Vector2(map_side, map_side)
	map.size = Vector2.ZERO
	if portrait:
		hdr.position.y = 10
		wth.position = Vector2(w - wth.size.x - 12, 70)
		map.position = Vector2(w - map_side - 28, 70 + wth.size.y + 8)
	else:
		wth.position = Vector2(w - wth.size.x - 12, 12)
		map.position = Vector2(w - map_side - 28, 12 + wth.size.y + 8)
	rel.position = Vector2(w - rel.size.x - 12, map.position.y + map_side + 24)
	tower.position = Vector2(12, 70 if portrait else 12)
	var dash: Control = get_node("Dash")
	dash.position = Vector2((w - dash.size.x) * 0.5, h - dash.size.y - 12)
	action_row.position = Vector2((w - action_row.size.x) * 0.5, dash.position.y - action_row.size.y - 8)
	var lts: Control = get_node("Lights")
	lts.position = Vector2((w - lts.size.x) * 0.5, h * 0.22)
	var pause: Control = get_node("Pause")
	var skip: Control = get_node("Skip")
	if portrait:
		pause.position = Vector2(w - pause.size.x - 12, 10)
		hdr.position.x = minf(hdr.position.x, w - pause.size.x - hdr.size.x - 24)
	else:
		pause.position = Vector2(hdr.position.x + hdr.size.x + 10, 10)
	skip.position = Vector2((w - skip.size.x) * 0.5, hdr.position.y + hdr.size.y + 8)
	touch_row.visible = touch_buttons
	touch_row.position = Vector2(w - touch_row.size.x - 12, h * 0.6 - touch_row.size.y - 10)
	var msg: Control = get_node("Message")
	# Under the header, or under the skip button when it is showing, never on top of it.
	var msg_top := skip.position.y + skip.size.y + 8 if skip.visible else hdr.position.y + hdr.size.y + 8
	msg.position = Vector2((w - msg.size.x) * 0.5, maxf(msg_top, 90 if not portrait else 140))


func _process(_delta: float) -> void:
	_layout()


# --- updates ----------------------------------------------------------------------------

func set_skip(show: bool, text: String) -> void:
	skip_button.visible = show
	skip_button.text = text


func set_track(points: PackedVector2Array) -> void:
	minimap.set_track(points)


func set_weather(air_c: float, track_c: float, wet: float) -> void:
	var sky := "Seco" if wet < 0.05 else ("Húmedo" if wet < 0.4 else "Lluvia")
	weather.text = "%s   Aire %d°   Pista %d°" % [sky, roundi(air_c), roundi(track_c)]


func _set_tower_row(k: int, pos: int, color: Color, code: String, value: String, player: bool, value_color := Color(0.85, 0.87, 0.9)) -> void:
	var r: Dictionary = tower_rows[k]
	r["root"].visible = true
	r["pos"].text = str(pos)
	r["bar"].color = color
	r["code"].text = code
	r["code"].add_theme_color_override("font_color", YELLOW if player else Color.WHITE)
	r["value"].text = value
	r["value"].add_theme_color_override("font_color", value_color)
	r["style"].bg_color = Color(0.25, 0.22, 0.05, 0.85) if player else BOX


func _hide_rows_from(k: int) -> void:
	for i in range(k, MAX_ROWS):
		tower_rows[i]["root"].visible = false


func show_race(s: RaceSession, player: RaceEntry, now: float) -> void:
	var order := s.classification()
	var rows := visible_rows()
	var player_pos := order.find(player) + 1
	# Show the leaders and keep the player in view when they are further back.
	var shown := []
	for k in order.size():
		if k < rows - 1 or (k == rows - 1 and player_pos <= rows):
			shown.append(k)
	if player_pos > rows:
		shown.append(player_pos - 1)
	var leader: RaceEntry = order[0]
	for i in shown.size():
		var k: int = shown[i]
		var e: RaceEntry = order[k]
		var value := ""
		var vcolor := Color(0.85, 0.87, 0.9)
		if e.status == RaceEntry.Status.RETIRED:
			value = "OUT"
			vcolor = Color(0.6, 0.6, 0.6)
		elif e.status == RaceEntry.Status.PIT:
			value = "BOXES"
			vcolor = YELLOW
		elif k == 0:
			value = "Líder" if s.phase != RaceSession.Phase.FINISHED else "Ganador"
		else:
			var laps_down := leader.laps_done - e.laps_done - (1 if e.lap_progress > leader.lap_progress else 0)
			value = RaceFormat.gap(s.interval(e), laps_down) if laps_down > 0 else "+%.1f" % s.interval(e)
		if e.code == s.fastest_lap_code and k != 0 and e.status != RaceEntry.Status.RETIRED and value != "BOXES":
			vcolor = PURPLE
		_set_tower_row(i, k + 1, Color(e.team["colors"]["primary"]), e.code, value, e.is_player, vcolor)
	_hide_rows_from(shown.size())
	var lap := clampi(leader.laps_done + 1, 1, s.laps)
	header.text = "VUELTA %d / %d" % [lap, s.laps] if s.phase != RaceSession.Phase.FINISHED else "BANDERA A CUADROS"
	subheader.text = "COCHE DE SEGURIDAD" if s.sc_active else ("PARADA OBLIGATORIA" if s.mandatory and player.fitted.is_empty() else "")
	subheader.visible = subheader.text != ""
	_show_lights(s)
	_show_relative(s, order, player)
	_show_dash(player.state, player.state.drs_open, player.drs_eligible, player.laps_done, player.last_lap, player.best_lap)
	var cars := []
	for e in s.entries:
		if e.status != RaceEntry.Status.RETIRED:
			cars.append({"pos": e.state.position, "color": Color(e.team["colors"]["primary"]).lightened(0.15), "player": e.is_player})
	minimap.cars = cars
	minimap.queue_redraw()
	_show_events(s.events, now)
	pit_button.text = "BOXES ✓" if player.pit_requested else "BOXES"
	compound_button.text = "Neumático: %s" % TyreNames.short(player.pit_compound)
	action_row.visible = player.status == RaceEntry.Status.RUNNING and s.phase == RaceSession.Phase.RACING


func _show_lights(s: RaceSession) -> void:
	var p: Control = get_node("Lights")
	p.visible = s.phase == RaceSession.Phase.LIGHTS or (s.phase == RaceSession.Phase.RACING and s.time - s.lights_out_at < 1.2)
	for k in 5:
		var on := k < s.lights_on
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(23)
		sb.bg_color = Color("#ff1a10") if on else Color(0.15, 0.15, 0.17)
		light_dots[k].add_theme_stylebox_override("panel", sb)


func _show_relative(s: RaceSession, order: Array, player: RaceEntry) -> void:
	var k := order.find(player)
	var lines := []
	if k > 0:
		var ahead: RaceEntry = order[k - 1]
		lines.append(["P%d %s" % [k, ahead.code], "-%.1f" % s.interval(player), Color(ahead.team["colors"]["primary"]).lightened(0.3)])
	lines.append(["P%d %s" % [k + 1, player.code], "", YELLOW])
	if k + 1 < order.size():
		var behind: RaceEntry = order[k + 1]
		if behind.status != RaceEntry.Status.RETIRED:
			lines.append(["P%d %s" % [k + 2, behind.code], "+%.1f" % s.interval(behind), Color(behind.team["colors"]["primary"]).lightened(0.3)])
	for i in relative_rows.size():
		var l: Label = relative_rows[i]
		l.visible = i < lines.size()
		if l.visible:
			l.text = "%-9s %s" % [lines[i][0], lines[i][1]]
			l.add_theme_color_override("font_color", lines[i][2])


func _show_dash(st: CarState, drs_open: bool, drs_ok: bool, laps_done: int, last_lap: float, best_lap: float) -> void:
	dash_speed.text = "%d km/h" % roundi(Units.kmh(st.speed()))
	var g := st.powertrain.gear
	dash_gear.text = "R" if g < 0 else ("N" if g == 0 else str(g))
	dash_rpm.value = clampf((st.powertrain.rpm - 4000.0) / 14000.0, 0.0, 1.0)
	dash_kers.value = st.powertrain.kers_energy_j / maxf(st.powertrain.spec.kers_energy_kj * 1000.0, 1.0)
	dash_drs.text = "DRS ABIERTO" if drs_open else ("DRS" if drs_ok else "DRS")
	dash_drs.add_theme_color_override("font_color", Color("#3ddc84") if drs_open else (Color.WHITE if drs_ok else Color(0.45, 0.45, 0.48)))
	var tyre := st.wheels[0].tyre
	var temp := 0.0
	var wear := 0.0
	for w in st.wheels:
		temp += w.tyre.temp_c / 4.0
		wear = maxf(wear, w.tyre.wear)
	dash_tyre.text = "%s  %d %%  %d°C" % [TyreNames.short(tyre.compound.id), roundi((1.0 - wear) * 100.0), roundi(temp)]
	dash_tyre.add_theme_color_override("font_color", TyreNames.color(tyre.compound.id))
	dash_lap.text = "Última %s · Mejor %s" % [RaceFormat.lap_time(last_lap if last_lap > 0.0 else INF), RaceFormat.lap_time(best_lap)]


func _show_events(events: Array, now: float) -> void:
	if events.size() > _last_event_count:
		message.text = events[-1]["text"]
		_message_until = now + 4.0
		_last_event_count = events.size()
	get_node("Message").visible = now < _message_until


func show_quali(q: QualiSession, car_color: Color, now: float) -> void:
	var table := q.live_table()
	var rows := mini(visible_rows(), table.size())
	var best := INF
	for r in table:
		best = minf(best, r["time"])
	var mine := q.player_position() - 1
	var shown := []
	for k in table.size():
		if k < rows - 1 or (k == rows - 1 and mine < rows):
			shown.append(k)
	if mine >= rows:
		shown.append(mine)
	var cut: int = QualiSession.CUTS[q.session] if q.session < QualiSession.CUTS.size() else 99
	for i in shown.size():
		var k: int = shown[i]
		var r: Dictionary = table[k]
		var t: float = r["time"]
		var value := RaceFormat.lap_time(t) if k == 0 or t == INF else "+%.3f" % (t - best)
		var vcolor := PURPLE if k == 0 and t < INF else (Color(1, 0.45, 0.4) if k >= cut else Color(0.85, 0.87, 0.9))
		_set_tower_row(i, k + 1, Color(q.model.team(r["team"])["colors"]["primary"]), r["code"], value, r["code"] == q.player_code, vcolor)
	_hide_rows_from(shown.size())
	header.text = "%s   %s" % [QualiSession.SESSION_NAMES[q.session], RaceFormat.clock(q.clock)]
	var lap_text := "Vuelta de salida"
	if q.on_timed_lap:
		lap_text = "Vuelta lanzada %s%s" % [RaceFormat.lap_time(q.elapsed - q.lap_start), "" if q.lap_valid else "  ANULADA"]
	elif q.clock <= 0.0:
		lap_text = "Bandera a cuadros"
	subheader.text = lap_text
	subheader.visible = true
	get_node("Lights").visible = false
	_show_dash(q.state, q.state.drs_open, true, 0, q.last_lap, q.best[q.session])
	for l in relative_rows:
		l.visible = false
	relative_rows[0].visible = true
	relative_rows[0].text = "P%d · corte P%d" % [mine + 1, cut] if cut < 99 else "P%d · por la pole" % (mine + 1)
	relative_rows[0].add_theme_color_override("font_color", YELLOW)
	minimap.cars = [{"pos": q.state.position, "color": car_color, "player": true}]
	minimap.queue_redraw()
	_show_events(q.events, now)
	action_row.visible = false
