extends TestCase

var spec := CarSpec.baseline_2012()


func _coast(_s, _t) -> DriverInput:
	return DriverInput.new()


func _distance_until(s: CarState, env: TrackEnvironment, kmh: float, input_fn: Callable) -> float:
	var start := s.position
	var t := 0.0
	while Units.kmh(s.speed()) > kmh and t < 30.0:
		VehicleSim.step(s, spec, input_fn.call(s, t), env, SimRunner.TICK)
		t += SimRunner.TICK
	return s.position.distance_to(start)


func test_gravel_traps_car() -> void:
	var env := TrackEnvironment.on(TrackFixtures.oval(Surface.Type.GRAVEL, 1.5, false, 120.0))
	var s := TrackFixtures.car_on_straight(spec, 100.0, 40.0, Units.ms(150.0))
	var d := _distance_until(s, env, 40.0, _coast)
	print("  gravel 150->40 km/h: %.1f m" % d)
	assert_true(d <= 90.0, "%.1f m" % d)



func test_car_can_drive_out_of_gravel() -> void:
	# Beached is the player's mistake, not a dead end: from a standstill, full throttle crawls out.
	var env := TrackEnvironment.on(TrackFixtures.oval(Surface.Type.GRAVEL, 1.5, false, 120.0))
	var s := TrackFixtures.car_on_straight(spec, 100.0, 40.0, 0.0)
	var full := func(_s, _t):
		var i := DriverInput.new()
		i.throttle = 1.0
		return i
	SimRunner.run(s, spec, env, 6.0, full)
	print("  gravel standstill + 6 s full throttle: %.1f km/h" % Units.kmh(s.speed()))
	assert_true(Units.kmh(s.speed()) >= 20.0, "%.1f km/h" % Units.kmh(s.speed()))

func test_grass_brakes_far_worse_than_asphalt() -> void:
	var brake := func(_s, _t):
		var i := DriverInput.new()
		i.brake = 1.0
		return i
	var env := TrackEnvironment.on(TrackFixtures.oval(Surface.Type.GRASS, 1.5, false, 120.0))
	var on_grass := _distance_until(TrackFixtures.car_on_straight(spec, 100.0, 40.0, Units.ms(150.0)), env, 50.0, brake)
	var on_asphalt := _distance_until(TrackFixtures.car_on_straight(spec, 100.0, 0.0, Units.ms(150.0)), env, 50.0, brake)
	print("  braking 150->50 km/h: grass %.1f m, asphalt %.1f m" % [on_grass, on_asphalt])
	assert_true(on_grass >= on_asphalt * 2.0)


func _yaw_variance(right_m: float, env: TrackEnvironment) -> float:
	var s := TrackFixtures.car_on_straight(spec, 100.0, right_m, Units.ms(200.0))
	var samples: Array[float] = []
	var steer := func(_s, _t):
		var i := DriverInput.new()
		i.throttle = 0.6
		i.steer = 0.01
		return i
	SimRunner.run(s, spec, env, 0.8, steer, func(st, _t): samples.append(st.yaw_rate))
	# Jitter: mean squared tick-to-tick change, so the slow steering transient
	# (present on both surfaces) does not mask the kerb's shaking.
	var jitter := 0.0
	for i in range(1, samples.size()):
		jitter += pow(samples[i] - samples[i - 1], 2)
	return jitter / (samples.size() - 1)


func test_high_kerb_destabilises() -> void:
	var env := TrackEnvironment.on(TrackFixtures.oval(Surface.Type.GRASS, 3.0, true))
	var on_kerb := _yaw_variance(7.5, env)
	var on_asphalt := _yaw_variance(0.0, env)
	assert_true(on_kerb > on_asphalt * 3.0 and on_kerb > 1e-6, "kerb %s asphalt %s" % [str(on_kerb), str(on_asphalt)])


func test_head_on_wall_stops_car() -> void:
	var env := TrackEnvironment.on(TrackFixtures.oval())
	var s := TrackFixtures.car_on_straight(spec, 300.0, 12.0, Units.ms(150.0), PI / 2)
	var impacts: Array[float] = [0.0]
	SimRunner.run(s, spec, env, 1.0, _coast, func(st, _t): impacts[0] = maxf(impacts[0], st.consume_impact()))
	var impact := impacts[0]
	assert_true(Units.kmh(s.speed()) < 35.0, "speed after %.1f km/h" % Units.kmh(s.speed()))
	assert_true(env.geometry.project(s.position).lateral > -20.0, "did not pass the wall")
	assert_true(impact > 30.0, "impact %.1f m/s" % impact)


func test_glancing_wall_keeps_speed() -> void:
	var env := TrackEnvironment.on(TrackFixtures.oval())
	var s := TrackFixtures.car_on_straight(spec, 300.0, 16.0, Units.ms(150.0), deg_to_rad(10.0))
	var impacts: Array[float] = [0.0]
	SimRunner.run(s, spec, env, 1.0, _coast, func(st, _t): impacts[0] = maxf(impacts[0], st.consume_impact()))
	var impact := impacts[0]
	assert_true(s.speed() > Units.ms(150.0) * 0.6, "speed after %.1f km/h" % Units.kmh(s.speed()))
	assert_between(impact, 3.0, 12.0)


func test_far_outside_track_is_wall_and_pushes_inside() -> void:
	var data := TestTrackBuilder.build()
	var env := TrackEnvironment.on(data)
	var c := data.points[50]
	var right := -(data.points[51] - c).normalized().orthogonal()
	var s := SimRunner.rolling(spec, 0.0)
	s.position = c + right * (data.wall_right[50] + 80.0)
	assert_eq(env.surface_at(s.position), Surface.Type.WALL)
	var before := absf(env.geometry.project(s.position).lateral)
	VehicleSim.step(s, spec, DriverInput.new(), env, SimRunner.TICK)
	var after := absf(env.geometry.project(s.position).lateral)
	assert_true(after < before and s.position.is_finite(), "before %.1f after %.1f" % [before, after])
