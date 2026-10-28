extends TestCase
## Qualifying driven by the player: session clock, runs from the garage, lap timing, track
## limits, knock-outs, and the AI's own runs on track.

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
	q.leave_garage()
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



func _ai_player(q: QualiSession) -> void:
	var ai := AiDriver.new(track, SpeedProfile.build(track, q.spec, &"soft"), AiSkill.level(AiSkill.LEGEND), 1)
	q.player_input = func(s: CarState, dt: float) -> DriverInput: return ai.drive(s, dt)
	q.assists = ai.assists


func _run_until(q: QualiSession, cond: Callable, max_s: float) -> void:
	var ticks := 0
	while not cond.call() and ticks < roundi(max_s * 120.0):
		q.step(SimClock.TICK)
		ticks += 1


func test_player_starts_parked_in_the_garage() -> void:
	var q := _quali()
	assert_eq(q.player.run, QualiCar.Run.GARAGE)
	var at := q.state.position
	for i in 240:
		q.step(SimClock.TICK)
	assert_true(q.state.position.distance_to(at) < 0.01, "waits in the box")
	assert_true(q.clock < 150.0, "the session clock runs meanwhile")


func test_full_run_garage_out_lap_timed_laps_in_lap_garage() -> void:
	var q := _quali("HAM", 600.0)
	_ai_player(q)
	q.leave_garage()
	assert_eq(q.player.run, QualiCar.Run.PIT_OUT)
	_run_until(q, func(): return q.player.run == QualiCar.Run.OUT_LAP, 60.0)
	assert_eq(q.player.run, QualiCar.Run.OUT_LAP, "joins the track at the pit exit")
	_run_until(q, func(): return q.player.run == QualiCar.Run.FLYING, 200.0)
	_run_until(q, func(): return q.best[0] < INF, 200.0)
	var first: float = q.best[0]
	assert_true(first > 80.0 and first < 110.0, "timed lap %.3f" % first)
	assert_eq(q.player.run, QualiCar.Run.FLYING, "the next timed lap starts straight away")
	q.request_pit()
	_run_until(q, func(): return q.player.run == QualiCar.Run.IN_LAP, 200.0)
	_run_until(q, func(): return q.player.run == QualiCar.Run.GARAGE, 250.0)
	assert_eq(q.player.run, QualiCar.Run.GARAGE, "back in the box after the in-lap")
	assert_true(q.state.speed() < 0.01)


func test_rivals_run_on_track_and_set_plausible_times() -> void:
	var q := _quali("HAM", 360.0)
	var seen_on_track := 0
	var ticks := 0
	while q.phase == QualiSession.Phase.RUNNING and ticks < 120 * 600:
		q.step(SimClock.TICK)
		ticks += 1
		if ticks % 1200 == 0:
			seen_on_track = maxi(seen_on_track, q.cars_on_track().size())
	assert_true(seen_on_track >= 5, "rivals out on track together (%d)" % seen_on_track)
	var timed := 0
	var ratio_sum := 0.0
	for c in q.cars:
		if c.is_player:
			continue
		if c.times[0] < INF:
			timed += 1
			ratio_sum += c.times[0] / (c.estimate * Qualifying.EVOLUTION[0])
	assert_true(timed >= 20, "%d rivals set a time" % timed)
	assert_near(ratio_sum / maxf(timed, 1.0), 1.0, 0.015, "driven laps match the calibrated estimate")
	var t := {}
	for c in q.cars:
		t[c.code] = c.times[0]
	assert_true(t["VET"] < t["KAR"] and t["BUT"] < t["DLR"], "Red Bull and McLaren ahead of HRT")


func test_knocked_out_rivals_stay_in_the_garage() -> void:
	var q := _quali("HAM")
	q.end_session()
	q.start_next()
	var out := 0
	for c in q.cars:
		if c.run == QualiCar.Run.OUT:
			out += 1
	assert_eq(out, 24 - QualiSession.CUTS[0])
