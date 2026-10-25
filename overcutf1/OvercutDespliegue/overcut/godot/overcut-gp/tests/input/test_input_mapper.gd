extends TestCase

var spec := CarSpec.baseline_2012()


func _raw_digital_throttle() -> InputMapper.Raw:
	var r := InputMapper.Raw.new()
	r.throttle = 1.0
	r.throttle_digital = true
	return r


func test_keyboard_ramp() -> void:
	var m := InputMapper.new()
	var s := CarState.create(spec, &"medium", 100.0)
	var t := 0.0
	while m.process_raw(_raw_digital_throttle(), s, SimRunner.TICK).throttle < 1.0 and t < 1.0:
		t += SimRunner.TICK
	assert_between(t, 0.13, 0.17)


func test_analog_throttle_is_immediate() -> void:
	var r := InputMapper.Raw.new()
	r.throttle = 0.7
	assert_near(InputMapper.new().process_raw(r, CarState.create(spec, &"medium", 100.0), SimRunner.TICK).throttle, 0.7, 1e-6)


func test_digital_steer_attenuated_at_speed() -> void:
	var m := InputMapper.new()
	var s := SimRunner.rolling(spec, 80.0)
	var r := InputMapper.Raw.new()
	r.steer = 1.0
	r.steer_digital = true
	var out: DriverInput
	for i in 120:
		out = m.process_raw(r, s, SimRunner.TICK)
	assert_between(out.steer, 0.35, 0.45)


func test_analog_steer_not_attenuated_without_assist() -> void:
	var r := InputMapper.Raw.new()
	r.steer = 1.0
	assert_near(InputMapper.new().process_raw(r, SimRunner.rolling(spec, 80.0), SimRunner.TICK).steer, 1.0, 1e-6)
