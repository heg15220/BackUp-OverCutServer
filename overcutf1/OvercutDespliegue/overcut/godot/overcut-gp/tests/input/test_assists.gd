extends TestCase

var spec := CarSpec.baseline_2012()


## Longest run of consecutive ticks where any of `wheel_ids` is sliding.
func _longest_slide(s: CarState, env: TrackEnvironment, seconds: float, raw_input: DriverInput, cfg: AssistConfig, wheel_ids: Array) -> int:
	var longest := [0, 0]
	var input_fn := func(st, _t): return Assists.apply(raw_input, st, spec, cfg)
	SimRunner.run(s, spec, env, seconds, input_fn, func(st, _t):
		var any := false
		for i in wheel_ids:
			any = any or st.wheels[i].sliding
		longest[1] = longest[1] + 1 if any else 0
		longest[0] = maxi(longest[0], longest[1]))
	return longest[0]


func _cfg(tc: bool, abs_on: bool) -> AssistConfig:
	var c := AssistConfig.new()
	c.traction_control = tc
	c.abs = abs_on
	return c


func test_tc_prevents_rear_slide_in_wet() -> void:
	var env := TrackEnvironment.flat()
	env.water = 0.4
	var full := DriverInput.new()
	full.throttle = 1.0
	var with_tc := _longest_slide(SimRunner.rolling(spec, Units.ms(60.0)), env, 3.0, full, _cfg(true, false), [CarState.RL, CarState.RR])
	var without := _longest_slide(SimRunner.rolling(spec, Units.ms(60.0)), env, 3.0, full, _cfg(false, false), [CarState.RL, CarState.RR])
	assert_true(with_tc <= 5, "TC on: %d ticks" % with_tc)
	assert_true(without > 5, "TC off: %d ticks" % without)


func test_abs_prevents_front_lock() -> void:
	var stomp := DriverInput.new()
	stomp.brake = 1.0
	var with_abs := _longest_slide(SimRunner.rolling(spec, Units.ms(250.0)), TrackEnvironment.flat(), 3.0, stomp, _cfg(false, true), [CarState.FL, CarState.FR])
	var without := _longest_slide(SimRunner.rolling(spec, Units.ms(250.0)), TrackEnvironment.flat(), 3.0, stomp, _cfg(false, false), [CarState.FL, CarState.FR])
	assert_true(with_abs <= 5, "ABS on: %d ticks" % with_abs)
	assert_true(without > 5, "ABS off: %d ticks" % without)


func test_auto_gearbox_flag_follows_config() -> void:
	var s := CarState.create(spec, &"medium", 100.0)
	var c := AssistConfig.new()
	c.auto_gearbox = false
	Assists.apply(DriverInput.new(), s, spec, c)
	assert_true(not s.auto_gearbox)
