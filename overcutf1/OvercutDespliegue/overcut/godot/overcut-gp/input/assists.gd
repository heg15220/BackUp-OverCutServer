class_name Assists
## Driver aids. They act on the input, never on the physics: traction control caps
## the throttle and ABS caps the brake so the tyres stay just under the grip limit
## measured in the previous substep (what is left after the cornering force).

## Fraction of the remaining grip the aids aim for.
const TARGET_USAGE := 0.92


static func apply(input: DriverInput, state: CarState, spec: CarSpec, cfg: AssistConfig) -> DriverInput:
	state.auto_gearbox = cfg.auto_gearbox
	var out := input.copy()
	if cfg.traction_control and out.throttle > 0.0:
		var capacity := _fx_capacity(state.wheels[CarState.RL]) + _fx_capacity(state.wheels[CarState.RR])
		var full := state.powertrain.full_drive_force()
		if full > 0.0:
			out.throttle = minf(out.throttle, capacity / full)
	if cfg.abs and out.brake > 0.0:
		var cap := 1.0
		for i in 4:
			var bias := spec.brake_bias_front if i < 2 else 1.0 - spec.brake_bias_front
			var per_wheel_full := spec.max_brake_force_n * bias * 0.5
			cap = minf(cap, _fx_capacity(state.wheels[i]) / per_wheel_full)
		out.brake = minf(out.brake, cap)
	return out


static func _fx_capacity(w: WheelState) -> float:
	var grip := w.avail_n * TARGET_USAGE
	return sqrt(maxf(0.0, grip * grip - w.fy * w.fy))
