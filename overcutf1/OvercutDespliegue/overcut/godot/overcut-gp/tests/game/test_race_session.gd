extends TestCase
## Race weekend rules and a full race simulated headless.

var model := SeasonModel.load_2012()
var track := TrackLoader.load_track("res://data/tracks/melbourne_2012.json")


func test_points_2012() -> void:
	var table: Array = model.data["points"]
	assert_eq(RaceRules.points_for(1, table), 25)
	assert_eq(RaceRules.points_for(10, table), 1)
	assert_eq(RaceRules.points_for(11, table), 0)


func test_race_lengths() -> void:
	assert_eq(RaceRules.race_laps(58, RaceRules.Length.LAPS_3), 3)
	assert_eq(RaceRules.race_laps(58, RaceRules.Length.LAPS_5), 5)
	assert_eq(RaceRules.race_laps(58, RaceRules.Length.PERCENT_25), 15)
	assert_eq(RaceRules.race_laps(58, RaceRules.Length.PERCENT_50), 29)
	assert_true(RaceRules.mandatory_stop(RaceRules.Length.PERCENT_25))
	assert_true(not RaceRules.mandatory_stop(RaceRules.Length.LAPS_5))


func test_mandatory_compound_change() -> void:
	# Started on softs: the mandatory stop must fit something else; later stops may be softs again.
	assert_true(not RaceRules.stop_rule_ok(&"soft", [], true), "no stop")
	assert_true(not RaceRules.stop_rule_ok(&"soft", [&"soft"], true), "softs again")
	assert_true(RaceRules.stop_rule_ok(&"soft", [&"medium"], true))
	assert_true(RaceRules.stop_rule_ok(&"soft", [&"medium", &"soft"], true))
	assert_true(RaceRules.stop_rule_ok(&"soft", [], false), "not required in short races")
	assert_true(RaceRules.stop_rule_ok(&"intermediate", [], true), "wet race exempt")


func test_107_percent_rule() -> void:
	assert_true(RaceRules.within_107(90.0, 86.0))
	assert_true(not RaceRules.within_107(93.0, 86.0))


func _session(laps: int, player_code := "") -> RaceSession:
	var s := RaceSession.new()
	s.setup(track, model, "australia", laps, false, AiSkill.PROFESSIONAL, player_code, 7)
	return s


func test_three_lap_race_runs_to_the_flag() -> void:
	var s := _session(3)
	var t0 := Time.get_ticks_msec()
	var guard := 0
	while s.phase != RaceSession.Phase.FINISHED and guard < 120 * 60 * 8:
		s.step(SimClock.TICK)
		guard += 1
	print("  3-lap race simulated in %d ms (%d ticks)" % [Time.get_ticks_msec() - t0, guard])
	assert_eq(s.phase, RaceSession.Phase.FINISHED)
	var cls := s.classification()
	assert_eq(cls.size(), s.entries.size())
	var winner: RaceEntry = cls[0]
	assert_true(winner.status == RaceEntry.Status.FINISHED and winner.laps_done == 3)
	assert_between(winner.finish_time, 3 * 80.0, 3 * 120.0)
	for e in cls:
		assert_true(e.state.position.is_finite(), e.code)
	var finishers := cls.filter(func(e): return e.status == RaceEntry.Status.FINISHED)
	assert_true(finishers.size() >= 15, "%d finishers" % finishers.size())


func test_race_finishes_without_player() -> void:
	var s := _session(3, "HAM")
	var player := s.player_entry()
	player.retire("Abandono del jugador", s.time)
	var guard := 0
	while s.phase != RaceSession.Phase.FINISHED and guard < 120 * 60 * 8:
		s.step(SimClock.TICK)
		guard += 1
	assert_eq(s.phase, RaceSession.Phase.FINISHED)
	assert_eq(player.status, RaceEntry.Status.RETIRED)


func test_jump_start_is_penalised() -> void:
	var s := _session(3, "HAM")
	var player := s.player_entry()
	s.player_input = func(_st, _dt):
		var i := DriverInput.new()
		i.throttle = 1.0  # flat out from the moment the lights come on
		return i
	while s.phase != RaceSession.Phase.RACING:
		s.step(SimClock.TICK)
	assert_true(player.penalty_s >= RaceRules.JUMP_START_PENALTY_S, "jump start penalty")


func test_hrt_misses_the_107_percent_cut() -> void:
	var q := Qualifying.simulate(track, model, "australia", AiSkill.LEGEND, 11)
	var dnq := q.results.filter(func(r): return not r["within_107"])
	var codes := dnq.map(func(r): return r["code"])
	assert_true("KAR" in codes and "DLR" in codes, "HRT out, as in 2012: %s" % str(codes))
	assert_eq(q.results[0]["team"] in ["mclaren", "lotus-f1", "mercedes", "red-bull"], true)
