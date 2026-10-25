class_name SimRunner
## Test helper: steps a car at the 120 Hz physics rate, asking input_fn(state, t)
## for a DriverInput every tick. on_tick(state, t), when given, observes each tick.

const TICK := 1.0 / 120.0


static func run(state: CarState, spec: CarSpec, env: TrackEnvironment, seconds: float, input_fn: Callable, on_tick := Callable()) -> void:
	var t := 0.0
	var ticks := roundi(seconds / TICK)
	for i in ticks:
		var input: DriverInput = input_fn.call(state, t)
		VehicleSim.step(state, spec, input, env, TICK)
		t += TICK
		if on_tick.is_valid():
			on_tick.call(state, t)


static func full_throttle(state: CarState, _t: float) -> DriverInput:
	var i := DriverInput.new()
	i.throttle = 1.0
	return i


## A car already rolling straight ahead (heading 0) at speed_ms.
static func rolling(spec: CarSpec, speed_ms: float, compound := &"medium", tyre_c := 105.0) -> CarState:
	var s := CarState.create(spec, compound, tyre_c)
	s.velocity = Vector2(speed_ms, 0.0)
	var pt := s.powertrain
	pt.gear = spec.gear_ratios.size()
	while pt.gear > 1 and pt.speed_at(Powertrain.UPSHIFT_RPM, pt.gear - 1) > speed_ms:
		pt.gear -= 1
	pt.update_rpm(speed_ms)
	return s
