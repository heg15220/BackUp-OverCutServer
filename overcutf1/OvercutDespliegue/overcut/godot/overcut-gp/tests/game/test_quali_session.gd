extends TestCase
## Qualifying driven by the player: session clock, lap timing, track limits and knock-outs.

var model := SeasonModel.load_2012()
var track := TrackLoader.load_track("res://data/tracks/melbourne_2012.json")


func _quali(code := "HAM", q1 := 150.0) -> QualiSession:
	var q := QualiSession.new()
	q.setup(track, model, "australia", AiSkill.PROFESSIONAL, code, 11, [q1, 120.0, 100.0])
	return q


func test_ai_times_do_not_depend_on_the_players_laps() -> void:
	var a := Qualifying.simulate(track, model, "australia", AiSkill.PROFESSIONAL, 5, "HAM", {0: 85.0})
	var b := Qualifying.simulate(track, model, "australia", AiSkill.PROFESSIONAL, 5, "HAM", {0: 99.0})
	var ta := {}
	for r in a.results:
		ta[r["code"]] = r["q1"]
	for r in b.results:
		if r["code"] != "HAM":
			assert_near(r["q1"], ta[r["code"]], 1e-6, r["code"])


func test_player_lap_is_timed_after_the_out_lap() -> void:
	var q := _quali("HAM", 400.0)
	var ai := AiDriver.new(track, SpeedProfile.build(track, q.spec, &"soft"), AiSkill.level(AiSkill.LEGEND), 1)
	q.player_input = func(s: CarState, dt: float) -> DriverInput: return ai.drive(s, dt)
	q.assists = ai.assists
	var ticks := 0
	while q.best[0] == INF and ticks < 120 * 300:
		q.step(SimClock.TICK)
		ticks += 1
	assert_true(q.best[0] > 80.0 and q.best[0] < 110.0, "timed lap %.3f" % q.best[0])
	assert_true(q.live_table().size() >= 1)


func test_skipping_a_session_without_driving_uses_the_estimate_and_advances() -> void:
	var q := _quali("HAM")
	q.end_session()
	assert_eq(q.phase, QualiSession.Phase.BETWEEN, "McLaren gets through Q1 on its estimate")
	q.start_next()
	assert_eq(q.session, 1)
	assert_near(q.clock, 120.0, 1e-6)


func test_slow_car_is_knocked_out_in_q1() -> void:
	var q := _quali("KAR")
	q.end_session()
	assert_eq(q.phase, QualiSession.Phase.DONE, "HRT out in Q1")
	assert_eq(q.eliminated_in, 0)
	var grid := q.final_result().grid_codes("KAR")
	assert_eq(grid[-1], "KAR", "starts from the back")


func test_lap_off_the_track_is_deleted() -> void:
	var q := _quali()
	q.on_timed_lap = true
	q.lap_start = 0.0
	for w in q.state.wheels:
		w.surface = Surface.Type.GRASS
	q.check_limits()
	assert_true(not q.lap_valid)
