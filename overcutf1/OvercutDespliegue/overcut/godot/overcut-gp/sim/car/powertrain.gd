class_name Powertrain
extends RefCounted
## Engine, gearbox and KERS. Produces the drive force at the rear contact patches.

## Torque is flat from here to power_rpm; below it falls towards 60% at idle.
const TORQUE_PLATEAU_RPM := 11000.0
## A clutch-slipping launch holds the engine at least here in first gear.
const LAUNCH_RPM := 9000.0
const UPSHIFT_RPM := 17800.0
const DOWNSHIFT_TARGET_RPM := 16000.0
const ENGINE_BRAKE_NM := 30.0
## Minimum speed used to turn KERS power into force (avoids infinite force at rest).
const KERS_MIN_SPEED := 5.0

var spec: CarSpec
var gear := 1
var rpm := 4000.0
var kers_energy_j := 0.0
var _shift_timer := 0.0
var _peak_torque := 0.0


func _init(car: CarSpec) -> void:
	spec = car
	rpm = car.idle_rpm
	kers_energy_j = car.kers_energy_kj * 1000.0
	_peak_torque = car.max_power_kw * 1000.0 / (car.power_rpm * TAU / 60.0)


func engine_torque(at_rpm: float, throttle: float) -> float:
	if at_rpm > spec.rev_limit:
		return 0.0
	var full: float
	if at_rpm <= TORQUE_PLATEAU_RPM:
		var k := clampf((at_rpm - spec.idle_rpm) / (TORQUE_PLATEAU_RPM - spec.idle_rpm), 0.0, 1.0)
		full = _peak_torque * (0.6 + 0.4 * k)
	elif at_rpm <= spec.power_rpm:
		full = _peak_torque
	else:
		full = spec.max_power_kw * 1000.0 / (at_rpm * TAU / 60.0)  # constant power to the limiter
	if throttle < 0.05:
		# Engine braking only while the wheels drive the engine above idle (clutch open at rest).
		return -ENGINE_BRAKE_NM * maxf(0.0, at_rpm - spec.idle_rpm - 500.0) / (spec.rev_limit - spec.idle_rpm)
	return full * throttle


func speed_at(at_rpm: float, at_gear: int) -> float:
	return at_rpm * TAU / 60.0 / spec.gear_ratios[at_gear - 1] * spec.tyre_radius


func update_rpm(wheel_speed_ms: float) -> void:
	if gear <= 0:
		rpm = spec.idle_rpm
		return
	rpm = maxf(spec.idle_rpm, absf(wheel_speed_ms) / spec.tyre_radius * spec.gear_ratios[gear - 1] * 60.0 / TAU)


## Engine force at the ground at full throttle in the current gear, without side effects.
func full_drive_force() -> float:
	if gear <= 0:
		return 0.0
	var eval_rpm := maxf(rpm, LAUNCH_RPM) if gear == 1 else rpm
	return engine_torque(eval_rpm, 1.0) * spec.gear_ratios[gear - 1] * spec.drivetrain_eff / spec.tyre_radius


## Total longitudinal force at the ground from the engine (and KERS when requested).
func drive_force(throttle: float, kers_request: bool, dt: float) -> float:
	if gear <= 0:
		return 0.0
	var force := 0.0
	if _shift_timer > 0.0:
		_shift_timer -= dt
	else:
		var eval_rpm := maxf(rpm, LAUNCH_RPM) if gear == 1 and throttle > 0.05 else rpm
		force = engine_torque(eval_rpm, throttle) * spec.gear_ratios[gear - 1] * spec.drivetrain_eff / spec.tyre_radius
	if kers_request and throttle > 0.5 and kers_energy_j > 0.0:
		var power := minf(spec.kers_power_kw * 1000.0, kers_energy_j / dt)
		kers_energy_j -= power * dt
		var speed := maxf(speed_at(rpm, gear), KERS_MIN_SPEED)
		force += power / speed
	return force


func auto_shift() -> void:
	if gear <= 0:
		return
	if rpm > UPSHIFT_RPM and gear < spec.gear_ratios.size():
		shift(1)
	elif gear > 1 and rpm * spec.gear_ratios[gear - 2] / spec.gear_ratios[gear - 1] < DOWNSHIFT_TARGET_RPM:
		shift(-1)


func shift(direction: int) -> void:
	var target := clampi(gear + direction, 1, spec.gear_ratios.size())
	if target == gear:
		return
	rpm *= spec.gear_ratios[target - 1] / spec.gear_ratios[gear - 1]
	gear = target
	_shift_timer = spec.shift_time


func reset_kers_lap() -> void:
	kers_energy_j = spec.kers_energy_kj * 1000.0
