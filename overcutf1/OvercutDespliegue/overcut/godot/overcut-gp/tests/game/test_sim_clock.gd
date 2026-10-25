extends TestCase


func test_clock_caps_ticks() -> void:
	assert_true(SimClock.new().advance(1.0) <= SimClock.MAX_TICKS_PER_FRAME)
	assert_eq(SimClock.MAX_TICKS_PER_FRAME, 8)


func test_clock_accumulates() -> void:
	var c := SimClock.new()
	var n := c.advance(SimClock.TICK * 0.5) + c.advance(SimClock.TICK * 0.5) + c.advance(SimClock.TICK * 0.5)
	assert_eq(n, 1)
	assert_near(c.alpha(), 0.5, 1e-6)


func test_large_frame_delta_is_substepped() -> void:
	var spec := CarSpec.baseline_2012()
	var controller := CarController.new()
	controller.setup(spec, CarState.create(spec, &"medium", 100.0), TrackEnvironment.flat())
	controller.input_source = SimRunner.full_throttle
	var ticks := controller.advance(0.5)
	assert_true(ticks <= 8, "%d ticks" % ticks)
	assert_true(controller.state.position.is_finite() and controller.state.speed() > 0.0)
	controller.free()
