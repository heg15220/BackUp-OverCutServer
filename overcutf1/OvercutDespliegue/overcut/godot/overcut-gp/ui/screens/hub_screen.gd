class_name HubScreen
## Championship hub: the next Grand Prix, both standings and the last result.


static func build(app: App) -> Control:
	var c := app.champ
	var me := app.model.driver(c.player_code)
	var team := app.model.team(c.team_id)
	var p := UiKit.page("Mundial 2012", "%s · %s · %s" % [me["name"], team["name"], AiSkill.NAMES[c.level]])
	var col: VBoxContainer = p[1]
	var grid := UiKit.adaptive_grid(380)
	col.add_child(grid)
	grid.add_child(_next_gp(app))
	grid.add_child(_drivers(app))
	grid.add_child(_teams(app))
	if not c.results.is_empty():
		grid.add_child(_last_result(app))
	var row := HBoxContainer.new()
	col.add_child(row)
	var settings := UiKit.button("Ajustes", app.edit_settings)
	settings.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(settings)
	var leave := UiKit.button("Guardar y salir", func():
		c.save(app.save_path)
		app.go_title())
	leave.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(leave)
	return p[0]


static func _next_gp(app: App) -> Control:
	var c := app.champ
	var pn := UiKit.panel("Próxima carrera")
	var v: VBoxContainer = pn[1]
	if c.season_over():
		var champion: Array = c.driver_standings()[0]
		v.add_child(UiKit.label("Temporada terminada", 28))
		v.add_child(UiKit.label("Campeón del mundo: %s (%d puntos)" % [app.model.driver(champion[0])["name"], champion[1]], 20))
		v.add_child(UiKit.button("Nuevo campeonato", app.new_championship))
		return pn[0]
	var gp := c.next_gp()
	v.add_child(UiKit.label("Ronda %d de %d" % [c.round, app.model.data["calendar"].size()], 17, UiKit.MUTED))
	v.add_child(UiKit.label(app.gp_name(gp), 30))
	v.add_child(UiKit.label("%s · %s" % [app.circuit_name(gp), gp["date"]], 18, UiKit.MUTED))
	var laps := RaceRules.race_laps(int(gp["laps"]), c.length)
	var stop := " · parada obligatoria" if RaceRules.mandatory_stop(c.length) else ""
	v.add_child(UiKit.label("Clasificación Q1/Q2/Q3 y carrera a %d vueltas%s" % [laps, stop], 18))
	if c.round_playable() and App.TRACK_FILES.has(gp["circuit"]):
		v.add_child(UiKit.button("Ir al Gran Premio", app.play_round, 72))
	else:
		v.add_child(UiKit.label("Este circuito aún se está recreando: la carrera se simula con el ritmo real de 2012.", 16, UiKit.MUTED))
		v.add_child(UiKit.button("Simular Gran Premio", app.play_round, 72))
	return pn[0]


static func _drivers(app: App) -> Control:
	var pn := UiKit.panel("Pilotos")
	var v: VBoxContainer = pn[1]
	var rows := app.champ.driver_standings()
	for k in rows.size():
		var d := app.model.driver(rows[k][0])
		var color := Color(app.model.team(d["team"])["colors"]["primary"])
		v.add_child(UiKit.table_row(str(k + 1), color, d["name"], "%d" % rows[k][1], d["code"] == app.champ.player_code))
	return pn[0]


static func _teams(app: App) -> Control:
	var pn := UiKit.panel("Constructores")
	var v: VBoxContainer = pn[1]
	var rows := app.champ.team_standings()
	for k in rows.size():
		var t := app.model.team(rows[k][0])
		v.add_child(UiKit.table_row(str(k + 1), Color(t["colors"]["primary"]), t["name"], "%d" % rows[k][1], t["id"] == app.champ.team_id))
	return pn[0]


static func _last_result(app: App) -> Control:
	var last: Dictionary = app.champ.results[-1]
	var gp := {}
	for g in app.model.data["calendar"]:
		if g["id"] == last["gp"]:
			gp = g
	var pn := UiKit.panel("Último resultado · " + app.gp_name(gp))
	var v: VBoxContainer = pn[1]
	var order: Array = last["order"]
	for k in mini(10, order.size()):
		var d := app.model.driver(order[k])
		v.add_child(UiKit.table_row(str(k + 1), Color(app.model.team(d["team"])["colors"]["primary"]), d["name"], "", d["code"] == app.champ.player_code))
	var mine := order.find(app.champ.player_code)
	v.add_child(UiKit.label("Tú: %s" % ("P%d" % (mine + 1) if mine >= 0 else "abandono"), 18, UiKit.MUTED))
	return pn[0]
