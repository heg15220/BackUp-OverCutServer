class_name Assists
## Driver aids. They switch on the per-wheel ABS and traction control in the physics
## (no extra grip, only a limit on how much of the tyre the brake and drive may use).

## Fraction of the remaining grip the aids aim for.
const TARGET_USAGE := 0.92


static func apply(input: DriverInput, state: CarState, spec: CarSpec, cfg: AssistConfig) -> DriverInput:
	state.auto_gearbox = cfg.auto_gearbox
	# ABS and traction control act per wheel inside the physics, like the real systems.
	state.abs_enabled = cfg.abs
	state.tc_enabled = cfg.traction_control
	state.esc_enabled = cfg.stability_control
	var out := input.copy()
	if cfg.traction_control and out.kers and state.powertrain.gear >= 1:
		# KERS alone would spin the rears: hold it back.
		var kers_force := spec.kers_power_kw * 1000.0 / maxf(state.speed(), Powertrain.KERS_MIN_SPEED)
		if kers_force > _fx_capacity(state.wheels[CarState.RL]) + _fx_capacity(state.wheels[CarState.RR]):
			out.kers = false
	return out


static func _fx_capacity(w: WheelState) -> float:
	var grip := w.avail_n * TARGET_USAGE
	return sqrt(maxf(0.0, grip * grip - w.fy * w.fy))
