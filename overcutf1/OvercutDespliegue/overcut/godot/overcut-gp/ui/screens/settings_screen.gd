class_name SettingsScreen
## Difficulty, race length, driver aids and camera. Used before the championship starts
## and from the hub (changes apply from the next Grand Prix).

const CAMERA := [["Cerca", 0.8], ["Media", 1.0], ["Lejos", 1.3]]
const AIDS := [["traction_control", "Control de tracción"], ["abs", "ABS"], ["auto_gearbox", "Cambio automático"], ["stability_control", "Control de estabilidad"]]


static func build(app: App, starting: bool) -> Control:
	var p := UiKit.page("Ajustes", "Puedes cambiarlos entre Grandes Premios")
	var col: VBoxContainer = p[1]
	var d := app.draft
	col.add_child(_section("Dificultad de la IA"))
	col.add_child(_choice(AiSkill.NAMES, d["level"], func(i): d["level"] = i))
	col.add_child(UiKit.label("Leyenda: los rivales al límite, como en la vida real. Muy difícil.", 15, UiKit.MUTED))
	col.add_child(_section("Duración de la carrera"))
	col.add_child(_choice(RaceRules.LENGTH_NAMES, d["length"], func(i): d["length"] = i))
	col.add_child(UiKit.label("En 25 % y 50 % hay una parada obligatoria con cambio de compuesto.", 15, UiKit.MUTED))
	col.add_child(_section("Ayudas a la conducción"))
	var aids := UiKit.adaptive_grid(260)
	col.add_child(aids)
	for a in AIDS:
		var t := CheckButton.new()
		t.text = a[1]
		t.button_pressed = bool(d["assists"].get(a[0], false))
		t.custom_minimum_size = Vector2(0, 56)
		t.toggled.connect(func(on): d["assists"][a[0]] = on)
		aids.add_child(t)
	col.add_child(_section("Cámara"))
	var current := 1
	for k in CAMERA.size():
		if is_equal_approx(CAMERA[k][1], d["camera"]):
			current = k
	col.add_child(_choice(CAMERA.map(func(c): return c[0]), current, func(i): d["camera"] = CAMERA[i][1]))
	col.add_child(UiKit.spacer(12))
	var row := HBoxContainer.new()
	col.add_child(row)
	var back := UiKit.button("Volver", func(): app.show_screen(func(): return DriverScreen.build(app)) if starting else app.go_hub())
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(back)
	var go := UiKit.button("Empezar el mundial" if starting else "Guardar", app.start_championship if starting else app.apply_settings)
	go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(go)
	return p[0]


static func _section(text: String) -> Label:
	var l := UiKit.label(text.to_upper(), 18, UiKit.ACCENT)
	l.custom_minimum_size = Vector2(0, 34)
	return l


## A row of toggle buttons where exactly one is selected.
static func _choice(options: Array, selected: int, on_pick: Callable) -> Control:
	var grid := UiKit.adaptive_grid(190)
	var group := ButtonGroup.new()
	for k in options.size():
		var b := Button.new()
		b.text = options[k]
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = k == selected
		b.custom_minimum_size = Vector2(0, 56)
		b.pressed.connect(func(): on_pick.call(k))
		grid.add_child(b)
	return grid
