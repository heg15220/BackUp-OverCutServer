class_name ResultsScreen
## Official race classification with the points scored, then back to the hub.
## rows: [{code, status ("" or retirement reason), gap (text), points}] in finishing order.


static func build(app: App, gp: Dictionary, rows: Array, fastest: String) -> Control:
	var p := UiKit.page("Resultados oficiales", app.gp_name(gp) + " · " + app.circuit_name(gp))
	var col: VBoxContainer = p[1]
	var pn := UiKit.panel("Clasificación de la carrera")
	col.add_child(pn[0])
	var v: VBoxContainer = pn[1]
	var pos := 0
	for r in rows:
		var d := app.model.driver(r["code"])
		var color := Color(app.model.team(d["team"])["colors"]["primary"])
		var classified: bool = r["status"] == ""
		if classified:
			pos += 1
		var value: String = r["gap"] if classified else r["status"]
		if r.get("points", 0) > 0:
			value += "   +%d" % r["points"]
		v.add_child(UiKit.table_row(str(pos) if classified else "—", color, "%s  %s" % [d["code"], d["name"]], value, r["code"] == app.champ.player_code))
	if fastest != "":
		col.add_child(UiKit.label("Vuelta rápida: %s" % app.model.driver(fastest).get("name", fastest), 18, Color("#b36bff")))
	col.add_child(UiKit.button("Continuar", app.go_hub, 72))
	return p[0]
