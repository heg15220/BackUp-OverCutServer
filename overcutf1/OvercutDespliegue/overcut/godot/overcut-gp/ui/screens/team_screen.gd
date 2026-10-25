class_name TeamScreen
## Team choice: livery colours, chassis and engine, and the car's real pace in 2012.


static func build(app: App) -> Control:
	var p := UiKit.page("Elige equipo", "Temporada 2012 · Ritmo: diferencia media en clasificación con el coche más rápido")
	var col: VBoxContainer = p[1]
	var grid := UiKit.adaptive_grid(330)
	col.add_child(grid)
	for t in app.model.data["teams"]:
		grid.add_child(_card(app, t))
	col.add_child(UiKit.button("Volver", func(): app.show_screen(func(): return SeasonScreen.build(app))))
	return p[0]


## Mean qualifying gap to the fastest team over the season, in percent.
static func season_gap(model: SeasonModel, team_id: String) -> float:
	var total := 0.0
	var n := 0
	for gp in model.data["pace"]:
		if model.data["pace"][gp].has(team_id):
			total += float(model.data["pace"][gp][team_id])
			n += 1
	return total / maxf(n, 1)


static func _card(app: App, t: Dictionary) -> Control:
	var c: Dictionary = t["colors"]
	var names := []
	for d in app.model.starters():
		if d["team"] == t["id"]:
			names.append(d["last_name"])
	var gap := season_gap(app.model, t["id"])
	var b := UiKit.card_button(func(): app.pick_team(t["id"]), [
		UiKit.color_chip([c["primary"], c["secondary"], c["accent"]], Vector2(90, 10)),
		UiKit.label(t["name"], 26),
		UiKit.label("%s · %s" % [t["chassis"], t["engine"]], 17, UiKit.MUTED),
		UiKit.label(" · ".join(names), 17),
		UiKit.label("Ritmo: +%.2f %%" % gap if gap > 0.005 else "Ritmo: referencia", 16, UiKit.GOOD if gap < 0.6 else UiKit.MUTED),
	])
	return b
