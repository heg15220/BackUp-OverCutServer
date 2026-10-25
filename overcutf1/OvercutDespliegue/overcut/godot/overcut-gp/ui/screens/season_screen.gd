class_name SeasonScreen
## Season choice: 2012 now; the other seasons from 1980 come in later releases.


static func build(app: App) -> Control:
	var p := UiKit.page("Elige temporada", "Cada temporada con sus equipos, pilotos, coches y reglamento reales")
	var col: VBoxContainer = p[1]
	var grid := UiKit.adaptive_grid(320)
	col.add_child(grid)
	grid.add_child(UiKit.button("2012\n20 Grandes Premios · 12 equipos · 24 pilotos", func(): app.show_screen(func(): return TeamScreen.build(app)), 110))
	for year in [2013, 2011, 2010]:
		var s := UiKit.button("%d\nPróximamente" % year, func(): pass, 110)
		s.disabled = true
		grid.add_child(s)
	col.add_child(UiKit.button("Volver", app.go_title))
	return p[0]
