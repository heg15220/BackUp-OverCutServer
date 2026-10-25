extends TestCase
## 2012 car and driver performance from the real season data.

var model := SeasonModel.load_2012()
var track := TrackLoader.load_track("res://data/tracks/melbourne_2012.json")


func _profile_lap(spec: CarSpec) -> float:
	var p := SpeedProfile.build(track, spec, &"soft")
	var t := 0.0
	for i in p.speeds.size():
		t += p.ds[i] / p.speeds[i]
	return t


func test_team_gaps_follow_the_real_melbourne_qualifying() -> void:
	var mclaren := _profile_lap(model.car_spec("mclaren", "australia", false))
	var ferrari := _profile_lap(model.car_spec("ferrari", "australia", false))
	var hrt := _profile_lap(model.car_spec("hrt", "australia", false))
	print("  profile laps: McLaren %.2f  Ferrari %.2f  HRT %.2f" % [mclaren, ferrari, hrt])
	assert_near(hrt / mclaren, 1.101, 0.02, "HRT ~10.1 % off McLaren")
	assert_near(ferrari / mclaren, 1.0185, 0.01, "Ferrari ~1.85 % off")


func test_ai_cars_get_the_driving_compensation_and_players_do_not() -> void:
	var ai := model.car_spec("mclaren", "australia", true)
	var player := model.car_spec("mclaren", "australia", false)
	assert_near(ai.base_mu / player.base_mu, SeasonModel.AI_GRIP_COMPENSATION, 1e-6)


func test_faster_team_mate_gets_more_pace() -> void:
	var ham := model.driver_skill("HAM", AiSkill.LEGEND)
	var but := model.driver_skill("BUT", AiSkill.LEGEND)
	assert_true(ham.pace > but.pace, "Hamilton out-qualified Button in 2012")


func test_legend_ai_mclaren_laps_near_the_real_pole() -> void:
	var spec := model.car_spec("mclaren", "australia", true)
	var profile := SpeedProfile.build(track, spec, &"soft")
	var env := TrackEnvironment.on(track.data)
	var s := CarState.create(spec, &"soft", 95.0)
	s.position = track.grid[0].position
	s.heading = track.grid[0].heading
	var ai := AiDriver.new(track, profile, AiSkill.level(AiSkill.LEGEND))
	var t := 0.0
	var last := -1.0
	var prev := s.track_index
	var lap := 0.0
	while t < 250.0 and lap == 0.0:
		VehicleSim.step(s, spec, Assists.apply(ai.drive(s, SimClock.TICK), s, spec, ai.assists), env, SimClock.TICK)
		t += SimClock.TICK
		if prev > track.data.points.size() - 20 and s.track_index < 20:
			if last >= 0.0:
				lap = t - last
			last = t
		prev = s.track_index
	print("  Legend AI McLaren flying lap (no DRS): %.3f s (real pole 84.922 with DRS)" % lap)
	assert_between(lap, 84.922 * 0.985, 84.922 * 1.025)
