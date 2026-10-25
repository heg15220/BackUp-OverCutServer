class_name DriverScreen
## Driver choice inside the team: the player takes that driver's seat.


static func build(app: App) -> Control:
	var team := app.model.team(app.draft["team"])
	var p := UiKit.page("Elige piloto", team["name"] + " · " + team["chassis"])
	var col: VBoxContainer = p[1]
	var grid := UiKit.adaptive_grid(330)
	col.add_child(grid)
	for d in app.model.starters():
		if d["team"] != team["id"]:
			continue
		var gap: float = d.get("quali_vs_teammate_pct", 0.0)
		var verdict := "más rápido" if gap < 0.0 else "más lento"
		grid.add_child(UiKit.card_button(func(): app.pick_driver(d["code"]), [
			UiKit.color_chip([d["helmet"]["main"], d["helmet"]["stripe"]], Vector2(60, 10)),
			UiKit.label("%d  %s" % [d["number"], d["name"]], 26),
			UiKit.label(d["code"], 18, UiKit.MUTED),
			UiKit.label("En clasificación, %.2f %% %s que su compañero" % [absf(gap), verdict], 16, UiKit.MUTED),
		]))
	col.add_child(UiKit.button("Volver", func(): app.show_screen(func(): return TeamScreen.build(app))))
	return p[0]
