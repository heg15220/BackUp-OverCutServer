extends TestCase
## Realism ranges for a 2012 F1 car on flat asphalt. If a value falls outside its
## range, tune the model's constants, never the range.

var spec := CarSpec.baseline_2012()


func _input(throttle := 0.0, brake := 0.0, steer := 0.0, drs := false) -> DriverInput:
	var i := DriverInput.new()
	i.throttle = throttle
	i.brake = brake
	i.steer = steer
	i.drs = drs
	return i


func _const(throttle := 0.0, brake := 0.0, steer := 0.0, drs := false) -> Callable:
	var i := _input(throttle, brake, steer, drs)
	return func(_s, _t): return i


func _time_to(target_kmh: float, fuel := 0.0) -> float:
	var s := CarState.create(spec, &"medium", 105.0)
	s.fuel_kg = fuel
	var t := 0.0
	while Units.kmh(s.speed()) < target_kmh and t < 30.0:
		VehicleSim.step(s, spec, _input(1.0), TrackEnvironment.flat(), SimRunner.TICK)
		t += SimRunner.TICK
	return t


func _braking_distance(from_kmh: float, to_kmh: float, tyre_c := 105.0, water := 0.0) -> float:
	var s := SimRunner.rolling(spec, Units.ms(from_kmh), &"medium", tyre_c)
	var env := TrackEnvironment.flat()
	env.water = water
	var start := s.position
	var t := 0.0
	while Units.kmh(s.speed()) > to_kmh and t < 30.0:
		VehicleSim.step(s, spec, _input(0.0, 1.0), env, SimRunner.TICK)
		t += SimRunner.TICK
	return s.position.distance_to(start)


## Ramp steer at (roughly) constant speed and report the peak lateral acceleration in g.
func _peak_lateral_g(speed_ms: float) -> float:
	var s := SimRunner.rolling(spec, speed_ms)
	var peak := 0.0
	var t := 0.0
	while t < 5.0:
		var i := _input()
		var err := speed_ms - s.speed()
		i.throttle = clampf(0.3 + err * 0.5, 0.0, 1.0)
		i.steer = clampf(t / 5.0, 0.0, 1.0)
		VehicleSim.step(s, spec, i, TrackEnvironment.flat(), SimRunner.TICK)
		if absf(err) < speed_ms * 0.05:
			peak = maxf(peak, absf(s.accel_local.y))
		t += SimRunner.TICK
	return peak / Units.G


func test_top_speed_2012() -> void:
	var s := CarState.create(spec, &"medium", 105.0)
	SimRunner.run(s, spec, TrackEnvironment.flat(), 60.0, _const(1.0))
	print("  top speed: %.1f km/h" % Units.kmh(s.speed()))
	assert_between(Units.kmh(s.speed()), 305.0, 330.0)


func test_drs_adds_top_speed() -> void:
	var a := CarState.create(spec, &"medium", 105.0)
	var b := CarState.create(spec, &"medium", 105.0)
	SimRunner.run(a, spec, TrackEnvironment.flat(), 60.0, _const(1.0))
	SimRunner.run(b, spec, TrackEnvironment.flat(), 60.0, _const(1.0, 0.0, 0.0, true))
	assert_between(Units.kmh(b.speed() - a.speed()), 8.0, 16.0)


func test_0_to_200_kmh() -> void:
	var t := _time_to(200.0)
	print("  0-200 km/h: %.2f s" % t)
	assert_between(t, 4.0, 6.0)


func test_200_to_300_kmh() -> void:
	var t := _time_between(200.0, 300.0, 0.0)
	print("  200-300 km/h: %.2f s" % t)
	assert_between(t, 5.0, 8.0)


func test_braking_300_to_100() -> void:
	var d := _braking_distance(300.0, 100.0)
	print("  300-100 km/h braking: %.1f m" % d)
	assert_between(d, 70.0, 130.0)


func test_cold_tyres_brake_longer() -> void:
	assert_true(_braking_distance(300.0, 100.0, 40.0) >= _braking_distance(300.0, 100.0) * 1.08)


func test_wet_slicks_brake_much_longer() -> void:
	assert_true(_braking_distance(300.0, 100.0, 105.0, 0.6) >= _braking_distance(300.0, 100.0) * 1.8)


func test_steady_state_lateral_g() -> void:
	var slow := _peak_lateral_g(32.0)
	var fast := _peak_lateral_g(72.0)
	print("  peak lateral: %.2f g @115 km/h, %.2f g @260 km/h" % [slow, fast])
	assert_between(slow, 1.8, 2.9, "slow corner (~R50)")
	assert_between(fast, 3.8, 5.6, "fast corner (~R300)")


func test_locked_fronts_lose_steering() -> void:
	var locked := SimRunner.rolling(spec, Units.ms(200.0))
	var trail := SimRunner.rolling(spec, Units.ms(200.0))
	SimRunner.run(locked, spec, TrackEnvironment.flat(), 1.0, _const(0.0, 1.0, 1.0))
	SimRunner.run(trail, spec, TrackEnvironment.flat(), 1.0, _const(0.0, 0.3, 1.0))
	assert_true(absf(locked.heading) < absf(trail.heading) * 0.5, "locked %f trail %f" % [locked.heading, trail.heading])


func test_deterministic() -> void:
	var inputs := func(_s, t): return _input(0.8, 0.0, sin(t * 1.3) * 0.6)
	var a := CarState.create(spec, &"soft", 95.0)
	var b := CarState.create(spec, &"soft", 95.0)
	SimRunner.run(a, spec, TrackEnvironment.flat(), 20.0, inputs)
	SimRunner.run(b, spec, TrackEnvironment.flat(), 20.0, inputs)
	assert_eq(a.position, b.position)
	assert_eq(a.heading, b.heading)


func test_at_rest_no_creep() -> void:
	var s := CarState.create(spec, &"medium", 105.0)
	SimRunner.run(s, spec, TrackEnvironment.flat(), 10.0, _const())
	assert_true(s.speed() < 0.01 and s.position.length() < 0.01 and absf(s.yaw_rate) < 1e-4)


func test_spin_recovery_no_nan() -> void:
	var s := CarState.create(spec, &"medium", 105.0)
	s.velocity = Vector2(0.0, 30.0)  # sideways to the heading
	s.yaw_rate = 3.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	var ok := [true]
	var inputs := func(_s, _t): return _input(rng.randf(), rng.randf() * 0.5, rng.randf_range(-1.0, 1.0))
	SimRunner.run(s, spec, TrackEnvironment.flat(), 5.0, inputs, func(st, _t):
		if not (st.position.is_finite() and st.velocity.is_finite() and is_finite(st.yaw_rate)) or st.speed() >= 100.0:
			ok[0] = false)
	assert_true(ok[0])


## 0-200 is traction-limited (extra fuel also loads the rear tyres), so the weight
## penalty is measured where the car is power-limited.
func test_fuel_weight_slows_acceleration() -> void:
	var full := _time_between(200.0, 300.0, 150.0)
	var empty := _time_between(200.0, 300.0, 0.0)
	print("  200-300 km/h: %.2f s full tank, %.2f s empty" % [full, empty])
	assert_true(full > empty * 1.1)


func _time_between(from_kmh: float, to_kmh: float, fuel: float) -> float:
	var s := SimRunner.rolling(spec, Units.ms(from_kmh))
	s.fuel_kg = fuel
	var t := 0.0
	while Units.kmh(s.speed()) < to_kmh and t < 60.0:
		VehicleSim.step(s, spec, _input(1.0), TrackEnvironment.flat(), SimRunner.TICK)
		t += SimRunner.TICK
	return t
