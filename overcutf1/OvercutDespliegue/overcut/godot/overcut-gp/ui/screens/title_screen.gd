class_name TitleScreen
## Title: new championship or continue the saved one.


static func build(app: App) -> Control:
	var p := UiKit.page("OVERCUT GP", "Fórmula 1 · Temporada 2012")
	var col: VBoxContainer = p[1]
	col.add_child(UiKit.label("Ocupa el asiento de un piloto real y pelea por el mundial con los equipos, coches y circuitos de 2012.", 20, UiKit.MUTED))
	col.add_child(UiKit.spacer(24))
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(minf(520, app.get_viewport().get_visible_rect().size.x - 48), 0)
	box.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	col.add_child(box)
	box.add_child(UiKit.button("Nuevo campeonato", app.new_championship, 72))
	var saved := Championship.load_from(app.save_path, app.model)
	var cont := UiKit.button("Continuar", app.continue_championship, 72)
	if saved == null:
		cont.disabled = true
	else:
		var d := app.model.driver(saved.player_code)
		cont.text = "Continuar · %s · Ronda %d" % [d.get("name", saved.player_code), mini(saved.round, 20)]
	box.add_child(cont)
	col.add_child(UiKit.spacer(24))
	col.add_child(UiKit.label("Teclado: flechas o WASD · Mando compatible · Controles táctiles en móvil y tableta", 16, UiKit.MUTED))
	col.add_child(UiKit.label("Datos: OpenStreetMap, f1db (CC BY 4.0), TUMFTM racetrack-database, Copernicus DEM. Sin patrocinadores.", 14, UiKit.MUTED))
	return p[0]
