extends TestCase
## AI drivers on the real Albert Park, using exactly the player's physics.

var track := TrackLoader.load_track("res://data/tracks/melbourne_2012.json")
## The AI drives the McLaren as the season model builds it for AI cars (with compensation).
var spec := SeasonModel.load_2012().car_spec("mclaren", "australia", true)


func _grid_car(slot := 0) -> CarState:
	var s := CarState.create(spec, &"soft", 95.0)
	s.position = track.grid[slot].position
	s.heading = track.grid[slot].heading
	return s


## Runs one AI car alone until it completes `laps` flying laps; returns lap times (s).
func _lap_times(level: int, laps := 1, max_s := 400.0) -> Array[float]:
	var env := TrackEnvironment.on(track.data)
	var profile := SpeedProfile.build(track, spec, &"soft")
	var s := _grid_car()
	var ai := AiDriver.new(track, profile, AiSkill.level(level))
	var times: Array[float] = []
	var t := 0.0
	var last_cross := -1.0
	var prev_index := s.track_index
	while t < max_s and times.size() < laps:
		var input := Assists.apply(ai.drive(s, SimClock.TICK), s, spec, ai.assists)
		VehicleSim.step(s, spec, input, env, SimClock.TICK)
		t += SimClock.TICK
		if prev_index > track.data.points.size() - 20 and s.track_index < 20:
			if last_cross >= 0.0:
				times.append(t - last_cross)
			last_cross = t
		prev_index = s.track_index
	return times


func test_speed_profile_slows_for_corners() -> void:
	var profile := SpeedProfile.build(track, spec, &"soft")
	var vmin := INF
	var vmax := 0.0
	for v in profile.speeds:
		vmin = minf(vmin, v)
		vmax = maxf(vmax, v)
	assert_between(Units.kmh(vmax), 280.0, 335.0, "top speed on the profile")
	assert_between(Units.kmh(vmin), 55.0, 140.0, "slowest corner on the profile")


func test_legend_ai_laps_albert_park_at_f1_pace() -> void:
	var times := _lap_times(AiSkill.LEGEND)
	assert_eq(times.size(), 1, "completed a flying lap")
	if times.size() == 1:
		print("  Legend AI lap (McLaren, soft): %.3f s" % times[0])
		assert_between(times[0], 83.0, 90.0)


func test_skill_levels_are_ordered() -> void:
	var beginner := _lap_times(AiSkill.BEGINNER)
	var legend := _lap_times(AiSkill.LEGEND)
	assert_true(beginner.size() == 1 and legend.size() == 1)
	if beginner.size() == 1 and legend.size() == 1:
		print("  Beginner %.2f s vs Legend %.2f s" % [beginner[0], legend[0]])
		assert_true(beginner[0] > legend[0] + 2.0)


func test_ai_recovers_from_wall() -> void:
	var env := TrackEnvironment.on(track.data)
	var profile := SpeedProfile.build(track, spec, &"soft")
	var s := _grid_car()
	# Point the car at the outside wall, stopped against it.
	var i := 200
	var p := track.data.points[i]
	var left := (track.data.points[i + 1] - p).normalized().orthogonal()
	s.position = p + left * (track.data.wall_left[i] - 2.8)
	s.heading = left.angle()
	s.track_index = -1
	var ai := AiDriver.new(track, profile, AiSkill.level(AiSkill.PROFESSIONAL))
	var geo := env.geometry
	var start_s := geo.project(s.position).s
	SimRunner.run(s, spec, env, 15.0, func(st, _t): return Assists.apply(ai.drive(st, SimClock.TICK), st, spec, ai.assists))  # the callback gets elapsed time, not dt
	var progress := fposmod(geo.project(s.position).s - start_s, geo.length())
	assert_true(progress > 80.0 and progress < geo.length() * 0.5, "progress %.1f m" % progress)


func test_car_contacts_separate() -> void:
	var a := _grid_car(0)
	var b := _grid_car(0)
	b.position = a.position + Vector2(0.6, 0.3)
	a.velocity = Vector2(20, 0)
	b.velocity = Vector2(10, 0)
	var cars: Array[CarState] = [a, b]
	CarContacts.resolve(cars, [spec, spec])
	assert_true(a.position.distance_to(b.position) >= 1.0, "separated to %.2f m" % a.position.distance_to(b.position))
	assert_true(a.position.is_finite() and b.position.is_finite() and a.velocity.is_finite())
	assert_true(a.last_impact_speed > 0.0 or b.last_impact_speed > 0.0)
