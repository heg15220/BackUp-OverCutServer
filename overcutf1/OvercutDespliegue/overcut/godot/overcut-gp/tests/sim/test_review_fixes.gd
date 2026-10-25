extends TestCase
## Regression tests for the final-review findings of plan 1.

var spec := CarSpec.baseline_2012()


func _input(throttle := 0.0, brake := 0.0, steer := 0.0, kers := false) -> DriverInput:
	var i := DriverInput.new()
	i.throttle = throttle
	i.brake = brake
	i.steer = steer
	i.kers = kers
	return i


func test_brake_and_throttle_at_rest_does_not_creep() -> void:
	var s := CarState.create(spec, &"medium", 100.0)
	var slid := [0]
	SimRunner.run(s, spec, TrackEnvironment.flat(), 10.0, func(_s, _t): return _input(1.0, 1.0), func(st, _t):
		if st.wheels[CarState.RL].sliding or st.wheels[CarState.RR].sliding:
			slid[0] += 1)
	assert_true(s.position.length() < 0.01, "moved %.3f m" % s.position.length())
	assert_eq(slid[0], 0)


func test_reverse_gets_a_car_off_a_wall() -> void:
	var env := TrackEnvironment.on(TrackFixtures.oval())
	var s := TrackFixtures.car_on_straight(spec, 300.0, 17.0, 0.0, PI / 2)  # nose against the right wall
	SimRunner.run(s, spec, env, 1.0, func(_s, _t): return _input(1.0))
	var start := s.position
	SimRunner.run(s, spec, env, 3.0, func(_s, _t): return _input(0.0, 1.0))  # hold brake: reverse
	assert_eq(s.powertrain.gear, -1)
	assert_true(s.position.distance_to(start) > 3.0 and s.position.y < start.y, "reversed %.2f m" % s.position.distance_to(start))
	SimRunner.run(s, spec, env, 2.0, func(_s, _t): return _input(1.0))
	assert_true(s.powertrain.gear >= 1, "throttle selects a forward gear again")


func test_hinted_projection_matches_full_for_off_track_points() -> void:
	var data := TestTrackBuilder.build()
	var geo := TrackGeometry.new(data)
	# A point in the infield between the two hairpin legs, closer to the far leg.
	# Leg A ends at the hairpin (~index 408); leg B is the left-hander after it (~420-444).
	var a := data.points[405]
	var best := 424
	for i in range(424, 444):
		if data.points[i].distance_to(a) < data.points[best].distance_to(a):
			best = i
	var gap := a.distance_to(data.points[best])
	assert_between(gap, 20.0, 45.0, "legs %.1f m apart" % gap)
	var pos := a.lerp(data.points[best], 0.6)
	assert_true(pos.distance_to(a) < data.wall_left[405] + 5.0, "inside the old hint reach")
	var full := geo.project(pos)
	var hinted := geo.project_hinted(pos, 405)
	assert_eq(hinted.index, full.index)
	assert_near(hinted.lateral, full.lateral, 1e-3)


func test_lateral_at_is_accurate_in_a_hairpin() -> void:
	var data := TestTrackBuilder.build()
	var geo := TrackGeometry.new(data)
	var i := 414
	var left := (data.points[i + 1] - data.points[i]).normalized().orthogonal()
	var base := data.points[i] - left * 5.5
	var p := geo.project(base)
	var fwd := (data.points[i + 1] - data.points[i]).normalized()
	for d in [1.84, 2.2, 2.95]:
		var pt: Vector2 = base + fwd * float(d)
		assert_near(geo.lateral_at(p, pt), geo.project(pt).lateral, 0.05, "%.2f m ahead" % d)


func test_sliding_sideways_keeps_most_of_the_grip() -> void:
	var peak := 5000.0
	assert_true(absf(TyreModel.lateral_with_peak(1.0, peak)) >= 0.7 * peak)
	assert_true(absf(TyreModel.lateral_with_peak(PI / 2, peak)) >= 0.7 * peak)
	assert_between(TyreModel.lateral_with_peak(0.25, peak) / peak, 0.70, 0.95)


func test_full_pedal_at_300_does_not_lock_but_does_at_low_speed() -> void:
	var fast := SimRunner.rolling(spec, Units.ms(300.0))
	var locked := [0]
	SimRunner.run(fast, spec, TrackEnvironment.flat(), 0.3, func(_s, _t): return _input(0.0, 1.0), func(st, _t):
		if st.wheels[CarState.FL].sliding:
			locked[0] += 1)
	assert_eq(locked[0], 0, "locked %d ticks at ~300 km/h" % locked[0])
	var slow := SimRunner.rolling(spec, Units.ms(120.0))
	SimRunner.run(slow, spec, TrackEnvironment.flat(), 0.2, func(_s, _t): return _input(0.0, 1.0))
	assert_true(slow.wheels[CarState.FL].sliding, "full pedal locks at 120 km/h")


func test_tc_accounts_for_kers() -> void:
	var cfg := AssistConfig.new()
	cfg.traction_control = true
	var s := SimRunner.rolling(spec, Units.ms(80.0))
	var run := [0, 0]
	var raw := _input(1.0, 0.0, 0.0, true)
	SimRunner.run(s, spec, TrackEnvironment.flat(), 2.0, func(st, _t): return Assists.apply(raw, st, spec, cfg), func(st, _t):
		run[1] = run[1] + 1 if (st.wheels[CarState.RL].sliding or st.wheels[CarState.RR].sliding) else 0
		run[0] = maxi(run[0], run[1]))
	assert_true(run[0] <= 5, "TC+KERS: %d ticks of wheelspin" % run[0])


func test_limited_slip_diff_sends_drive_to_the_gripping_wheel() -> void:
	var env := TrackEnvironment.on(TrackFixtures.oval(Surface.Type.GRASS, 0.0))
	var s := TrackFixtures.car_on_straight(spec, 200.0, -6.4, Units.ms(60.0))  # left wheels on grass
	# Enough drive to spin the grass wheel but not the one on asphalt.
	SimRunner.run(s, spec, env, 0.3, func(_s, _t): return _input(0.2))
	assert_eq(s.wheels[CarState.RL].surface, Surface.Type.GRASS)
	assert_true(not s.wheels[CarState.RR].sliding)
	var half := s.powertrain.full_drive_force() * 0.2 * 0.5
	assert_true(s.wheels[CarState.RR].fx > half * 1.05, "RR %.0f vs half the drive %.0f" % [s.wheels[CarState.RR].fx, half])
