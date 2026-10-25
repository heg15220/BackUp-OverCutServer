extends TestCase

const TICK := 1.0 / 120.0

var spec := CarSpec.baseline_2012()


func _car(speed_ms: float, surface := Surface.Type.ASPHALT) -> CarState:
	var s := CarState.create(spec, &"medium", 100.0)
	s.velocity = Vector2(speed_ms, 0.0)
	for w in s.wheels:
		w.surface = surface
	return s


## Runs the director for `seconds`; returns [pulses, times] where times[i] is when pulse i fired.
func _run(director: HapticsDirector, rec: RecordingHaptics, s: CarState, input: DriverInput, seconds: float) -> Array:
	var times: Array[float] = []
	for i in roundi(seconds / TICK):
		var before := rec.pulses.size()
		director.update(s, input, TICK)
		for k in rec.pulses.size() - before:
			times.append(director.time)
	return [rec.pulses, times]


func _director() -> Array:
	var rec := RecordingHaptics.new()
	var backends: Array[HapticsBackend] = [rec]
	return [HapticsDirector.new(backends), rec]


func test_kerb_pulses_scale_with_speed() -> void:
	var slow := _director()
	var fast := _director()
	var n_slow: int = _run(slow[0], slow[1], _car(20.0, Surface.Type.KERB_LOW), DriverInput.new(), 1.0)[0].size()
	var n_fast: int = _run(fast[0], fast[1], _car(80.0, Surface.Type.KERB_LOW), DriverInput.new(), 1.0)[0].size()
	assert_true(n_fast > n_slow and n_slow > 0, "slow %d fast %d" % [n_slow, n_fast])


func test_kerb_strength_follows_bump() -> void:
	var low := _director()
	var high := _director()
	var p_low: Array = _run(low[0], low[1], _car(40.0, Surface.Type.KERB_LOW), DriverInput.new(), 0.3)[0]
	var p_high: Array = _run(high[0], high[1], _car(40.0, Surface.Type.KERB_HIGH), DriverInput.new(), 0.3)[0]
	assert_near(p_low[0][0], 0.3 + 0.6 * Surface.bump(Surface.Type.KERB_LOW), 1e-6)
	assert_true(p_high[0][0] > p_low[0][0])
	assert_eq(p_low[0][1], 25)


func test_lock_pattern() -> void:
	var d := _director()
	var s := _car(50.0)
	s.wheels[CarState.FL].sliding = true
	var input := DriverInput.new()
	input.brake = 0.8
	var pulses: Array = _run(d[0], d[1], s, input, 1.0)[0]
	assert_between(pulses.size(), 10, 14)
	assert_near(pulses[0][0], 0.5, 1e-6)
	assert_eq(pulses[0][1], 40)


func test_wheelspin_pattern() -> void:
	var d := _director()
	var s := _car(20.0)
	s.wheels[CarState.RR].sliding = true
	var input := DriverInput.new()
	input.throttle = 1.0
	var pulses: Array = _run(d[0], d[1], s, input, 1.0)[0]
	assert_between(pulses.size(), 8, 11)
	assert_eq(pulses[0][1], 30)


func test_offtrack_pattern() -> void:
	var d := _director()
	var pulses: Array = _run(d[0], d[1], _car(30.0, Surface.Type.GRAVEL), DriverInput.new(), 1.0)[0]
	assert_between(pulses.size(), 7, 9)
	assert_near(pulses[0][0], 0.6, 1e-6)
	assert_eq(pulses[0][1], 50)


func test_impact_always_fires_and_scales() -> void:
	var d := _director()
	var director: HapticsDirector = d[0]
	var rec: RecordingHaptics = d[1]
	var s := _car(80.0, Surface.Type.KERB_HIGH)
	director.update(s, DriverInput.new(), TICK)  # a kerb pulse fires now
	s.last_impact_speed = 10.0
	director.update(s, DriverInput.new(), TICK)  # inside the 70 ms window, impact still fires
	assert_near(rec.pulses[-1][0], 0.4, 1e-6)
	assert_eq(rec.pulses[-1][1], 120)
	s.last_impact_speed = 60.0
	director.update(s, DriverInput.new(), TICK)
	assert_near(rec.pulses[-1][0], 1.0, 1e-6)
	assert_eq(rec.pulses[-1][1], 300)


func test_small_knocks_do_not_fire_impact() -> void:
	var d := _director()
	var s := _car(10.0)
	s.last_impact_speed = 2.0
	d[0].update(s, DriverInput.new(), TICK)
	assert_eq(d[1].pulses.size(), 0)


func test_rate_limit_70ms() -> void:
	var d := _director()
	var times: Array = _run(d[0], d[1], _car(90.0, Surface.Type.KERB_HIGH), DriverInput.new(), 1.0)[1]
	for i in range(1, times.size()):
		assert_true(times[i] - times[i - 1] >= 0.07 - 1e-6, "gap %f" % (times[i] - times[i - 1]))


func test_disabled_emits_nothing() -> void:
	var d := _director()
	d[0].enabled = false
	var s := _car(80.0, Surface.Type.GRAVEL)
	s.last_impact_speed = 30.0
	assert_eq(_run(d[0], d[1], s, DriverInput.new(), 1.0)[0].size(), 0)


func test_no_pulses_on_clean_asphalt() -> void:
	var d := _director()
	var input := DriverInput.new()
	input.throttle = 1.0
	assert_eq(_run(d[0], d[1], _car(60.0), input, 1.0)[0].size(), 0)
