class_name CarController
extends Node
## Owns one car's simulation and drives it at the fixed tick rate.
## input_source(state, dt) -> DriverInput supplies the driver (human or AI).

signal ticked

var spec: CarSpec
var state: CarState
var env: TrackEnvironment
var assists := AssistConfig.new()
var haptics: HapticsDirector
var input_source: Callable
var last_input := DriverInput.new()
## Pose before the last tick, for render interpolation.
var prev_position := Vector2.ZERO
var prev_heading := 0.0
var clock := SimClock.new()


func setup(car_spec: CarSpec, car_state: CarState, environment: TrackEnvironment) -> void:
	spec = car_spec
	state = car_state
	env = environment
	prev_position = state.position
	prev_heading = state.heading


func _physics_process(delta: float) -> void:
	advance(delta)


## Runs as many fixed ticks as frame_dt covers (capped); returns how many ran.
func advance(frame_dt: float) -> int:
	var ticks := clock.advance(frame_dt)
	for i in ticks:
		prev_position = state.position
		prev_heading = state.heading
		var raw: DriverInput = input_source.call(state, SimClock.TICK) if input_source.is_valid() else DriverInput.new()
		var input := Assists.apply(raw, state, spec, assists)
		VehicleSim.step(state, spec, input, env, SimClock.TICK)
		if haptics != null:
			haptics.update(state, input, SimClock.TICK)
		last_input = input
		ticked.emit()
	return ticks


func interpolated_position(alpha: float) -> Vector2:
	return prev_position.lerp(state.position, alpha)


func interpolated_heading(alpha: float) -> float:
	return lerp_angle(prev_heading, state.heading, alpha)
