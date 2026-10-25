extends TestCase
## The game's screens end to end, headless: new championship, a simulated round, the
## weekend scene (qualifying skipped, a few seconds of race) and the saved state.

const SAVE := "user://test_app_flow.json"


func _app() -> App:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	var app := App.new()
	app.save_path = SAVE
	tree.root.add_child(app)
	return app


func _frames(n: int) -> void:
	for i in n:
		await tree.process_frame


func _cleanup(app: App) -> void:
	tree.paused = false
	app.queue_free()
	await tree.process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))


func test_new_championship_through_the_menus() -> void:
	var app := _app()
	await _frames(2)
	assert_true(not app.has_save())
	app.new_championship()
	await _frames(1)
	app.show_screen(func(): return TeamScreen.build(app))
	await _frames(1)
	app.pick_team("ferrari")
	await _frames(1)
	app.pick_driver("ALO")
	await _frames(1)
	app.draft["length"] = RaceRules.Length.PERCENT_25
	app.start_championship()
	await _frames(2)
	assert_true(app.has_save())
	assert_eq(app.champ.player_code, "ALO")
	assert_eq(app.champ.length, RaceRules.Length.PERCENT_25)
	await _cleanup(app)


func test_unbuilt_round_is_simulated_and_scored() -> void:
	var app := _app()
	await _frames(1)
	app.champ = Championship.create(app.model, "mclaren", "HAM", AiSkill.LEGEND, RaceRules.Length.LAPS_3)
	app.champ.round = 2
	app.play_round()
	await _frames(2)
	assert_eq(app.champ.round, 3)
	var total := 0
	for code in app.champ.driver_points:
		total += app.champ.driver_points[code]
	assert_eq(total, 101, "25+18+15+12+10+8+6+4+2+1")
	app.go_hub()
	await _frames(2)
	await _cleanup(app)


func test_weekend_runs_qualifying_and_the_start() -> void:
	var app := _app()
	await _frames(1)
	app.champ = Championship.create(app.model, "mclaren", "HAM", AiSkill.PROFESSIONAL, RaceRules.Length.LAPS_3)
	app.play_round()
	await _frames(3)
	var w: RaceWeekend = app._weekend
	assert_true(w != null, "weekend started")
	assert_eq(w.stage, RaceWeekend.Stage.QUALI)
	for s in 3:
		if w.quali.phase == QualiSession.Phase.DONE:
			break
		w._skip()
		await _frames(2)
		if w.quali.phase == QualiSession.Phase.BETWEEN:
			w.quali.start_next()
			w.stage = RaceWeekend.Stage.QUALI
			w._show_quali_car()
	assert_eq(w.quali.phase, QualiSession.Phase.DONE)
	w._start_race(w.quali.final_result().grid_codes("HAM"))
	await _frames(2)
	for i in 120 * 8:
		w._tick()
	await _frames(2)
	assert_eq(w.session.phase, RaceSession.Phase.RACING, "lights out within 8 s")
	w._toggle_pit()
	assert_true(w.session.player_entry().pit_requested)
	var before := w.session.player_entry().pit_compound
	w._cycle_compound()
	assert_true(w.session.player_entry().pit_compound != before, "compound changes")
	await _cleanup(app)
