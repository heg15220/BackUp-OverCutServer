class_name SpeedProfile
extends RefCounted
## The fastest speed at every point of the racing line for a given car: limited by lateral
## grip (with downforce) in corners, then by traction/power accelerating out of them
## (forward pass) and by braking grip into them (backward pass), sharing the friction circle.

const GRIP_MARGIN := 0.97  ## of the measured skidpad peak: the line is not a steady circle
const MAX_SPEED := 95.0
## Share of the measured straight-line braking the profile asks for.
const BRAKE_SHARE := 0.85

var points := PackedVector2Array()  ## racing line in 2D
var speeds := PackedFloat32Array()  ## m/s
var curvature := PackedFloat32Array()
var ds := PackedFloat32Array()  ## distance from point i to i+1


static func build(track: LoadedTrack, spec: CarSpec, compound: StringName) -> SpeedProfile:
	var p := SpeedProfile.new()
	var d := track.data
	var n := d.points.size()
	p.points.resize(n)
	for i in n:
		var nrm := (d.points[(i + 1) % n] - d.points[(i - 1 + n) % n]).normalized().orthogonal()
		var off := track.racing_line[i] if track.racing_line.size() == n else 0.0
		p.points[i] = d.points[i] + nrm * off
	# Round off single-point kinks in the source data into arcs a car can actually drive.
	for sweep in 3:
		var smoothed := PackedVector2Array()
		smoothed.resize(n)
		for i in n:
			var acc := Vector2.ZERO
			for k in range(-2, 3):
				acc += p.points[(i + k + n) % n] * (3.0 - absf(k))
			smoothed[i] = acc / 9.0
		p.points = smoothed
	p.ds.resize(n)
	p.curvature.resize(n)
	var raw := PackedFloat32Array()
	raw.resize(n)
	for i in n:
		var a := p.points[(i - 1 + n) % n]
		var b := p.points[i]
		var c := p.points[(i + 1) % n]
		p.ds[i] = b.distance_to(c)
		var area2 := absf((b - a).cross(c - a))
		var denom := a.distance_to(b) * b.distance_to(c) * c.distance_to(a)
		raw[i] = 2.0 * area2 / denom if denom > 1e-9 else 0.0
	for i in n:  # light smoothing; the line itself is already smooth
		p.curvature[i] = (raw[(i - 1 + n) % n] + 2.0 * raw[i] + raw[(i + 1) % n]) / 4.0

	var lat := measure_lateral(spec, compound)
	p.speeds.resize(n)
	for i in n:
		var kappa := p.curvature[i]
		var v := MAX_SPEED
		if kappa > 1e-5:
			# v^2 * kappa = a_lat(v): fixed-point on the measured lateral envelope
			v = 30.0
			for it in 12:
				v = minf(MAX_SPEED, sqrt(_lookup(lat, v) / kappa))
		p.speeds[i] = v
	var env := measure_envelope(spec, compound)
	for sweep in 2:
		for step in n:  # forward: acceleration
			var i := step
			var j := (i + 1) % n
			var v := p.speeds[i]
			var share := sqrt(maxf(0.0, 1.0 - pow(minf(v * v * p.curvature[i] / _lookup(lat, v), 1.0), 2)))
			var a := _lookup(env[0], v) * share
			p.speeds[j] = minf(p.speeds[j], sqrt(maxf(0.0, v * v + 2.0 * a * p.ds[i])))
		for step in n:  # backward: braking
			var j := (n - 1 - step + n) % n
			var i := (j + 1) % n
			var v := p.speeds[i]
			var share := sqrt(maxf(0.0, 1.0 - pow(minf(v * v * p.curvature[j] / _lookup(lat, v), 1.0), 2)))
			var a := _lookup(env[1], v) * share * BRAKE_SHARE
			p.speeds[j] = minf(p.speeds[j], sqrt(v * v + 2.0 * a * p.ds[j]))
	return p


const ENVELOPE_STEP := 5.0  ## m/s per table entry
static var _lateral_cache := {}


## Peak steady lateral acceleration (m/s^2) at each speed, measured with the real physics
## like a skidpad: constant speed, constant steer held until it settles, the best settled
## value over a sweep of steering angles. Measured once on the 2012 baseline per compound
## and scaled for each car's downforce and grip (measuring every team would stall loading).
static func measure_lateral(spec: CarSpec, compound: StringName) -> PackedFloat32Array:
	var base_spec := CarSpec.baseline_2012()
	var key := String(compound)
	if not _lateral_cache.has(key):
		_lateral_cache[key] = _skidpad(base_spec, compound)
	var base: PackedFloat32Array = _lateral_cache[key]
	var out := PackedFloat32Array()
	out.resize(base.size())
	var kb := 0.5 * Units.AIR_DENSITY * base_spec.cl_a / base_spec.mass_kg
	var kt := 0.5 * Units.AIR_DENSITY * spec.cl_a / (spec.mass_kg)
	for b in base.size():
		var v := b * ENVELOPE_STEP
		out[b] = base[b] * (Units.G + kt * v * v) / (Units.G + kb * v * v) * (spec.base_mu / base_spec.base_mu)
	return out


static func _skidpad(spec: CarSpec, compound: StringName) -> PackedFloat32Array:
	var bins := int(MAX_SPEED / ENVELOPE_STEP) + 2
	var out := PackedFloat32Array()
	out.resize(bins)
	var flat := TrackEnvironment.flat()
	for b in range(2, bins, 2):  # every 10 m/s, interpolated between
		var v0 := minf(b * ENVELOPE_STEP, MAX_SPEED)
		var best := 0.0
		# Sweep up to the steer a kinematic 7 g turn would need (x1.6 for slip): fine steps at speed.
		var steer_max := minf(1.0, spec.wheelbase * 7.0 * Units.G / (v0 * v0) / spec.max_steer * 1.6)
		for steer_step in range(1, 13):
			var s := SimRunner_rolling(spec, v0, compound)
			var input := DriverInput.new()
			input.steer = steer_max * steer_step / 12.0
			var acc := 0.0
			var samples := 0
			var spun := false
			for k in 300:
				input.throttle = clampf(0.3 + (v0 - s.speed()) * 0.8, 0.0, 1.0)
				VehicleSim.step(s, spec, input, flat, SimClock.TICK)
				if absf(angle_difference(s.heading, s.velocity.angle())) > 0.35:
					spun = true
					break
				if k >= 240:
					acc += absf(s.speed() * s.yaw_rate)  # settled centripetal acceleration
					samples += 1
			if spun or samples == 0 or absf(s.speed() - v0) > v0 * 0.08:
				continue
			best = maxf(best, acc / samples)
		out[b] = best * GRIP_MARGIN
	for b in bins:
		if out[b] <= 0.0:
			var lo := b - 1
			var hi := mini(b + 1, bins - 1)
			if lo >= 0 and out[hi] > 0.0:
				out[b] = (out[lo] + out[hi]) * 0.5
			elif lo >= 0:
				out[b] = out[lo]
	out[0] = out[2] * 0.9
	out[1] = out[2] * 0.95
	return out


## A car rolling straight at speed (sim-side twin of the test helper, without depending on tests/).
static func SimRunner_rolling(spec: CarSpec, speed_ms: float, compound: StringName) -> CarState:
	var s := CarState.create(spec, compound, 95.0)
	s.velocity = Vector2(speed_ms, 0.0)
	s.tc_enabled = true
	var pt := s.powertrain
	pt.gear = spec.gear_ratios.size()
	while pt.gear > 1 and pt.speed_at(Powertrain.UPSHIFT_RPM, pt.gear - 1) > speed_ms:
		pt.gear -= 1
	pt.update_rpm(speed_ms)
	return s

## Measures the car's straight-line acceleration and braking (both with the aids on) at
## every speed by running the real physics, so the profile never asks for more than the
## car can do. Returns [accel_table, decel_table] indexed by speed / ENVELOPE_STEP.
static func measure_envelope(spec: CarSpec, compound: StringName) -> Array:
	var bins := int(MAX_SPEED / ENVELOPE_STEP) + 2
	var accel := PackedFloat32Array()
	var decel := PackedFloat32Array()
	accel.resize(bins)
	decel.resize(bins)
	var flat := TrackEnvironment.flat()
	var input := DriverInput.new()
	# accelerating from rest
	var s := CarState.create(spec, compound, 95.0)
	s.tc_enabled = true
	input.throttle = 1.0
	var prev := 0.0
	var best := 0.0
	var since_best := 0
	for k in 9000:
		VehicleSim.step(s, spec, input, flat, SimClock.TICK)
		var v := s.speed()
		var gain := (v - prev) / SimClock.TICK
		var b := int(v / ENVELOPE_STEP)
		if b < bins:
			accel[b] = maxf(accel[b], gain)
		prev = v
		if v > best + 0.05:
			best = v
			since_best = 0
		else:
			since_best += 1
		if v >= MAX_SPEED - 1.0 or since_best > 240:
			break  # top speed: no gain for 2 s (gear changes pause the drive briefly)
	# braking from the top
	s = CarState.create(spec, compound, 95.0)
	s.velocity = Vector2(MAX_SPEED, 0.0)
	s.abs_enabled = true
	s.powertrain.gear = spec.gear_ratios.size()
	input.throttle = 0.0
	input.brake = 1.0
	prev = MAX_SPEED
	for k in 1200:
		VehicleSim.step(s, spec, input, flat, SimClock.TICK)
		var v := s.speed()
		var b := int(v / ENVELOPE_STEP)
		if b < bins and k > 12:
			decel[b] = maxf(decel[b], (prev - v) / SimClock.TICK)
		prev = v
		if v < 3.0:
			break
	# Bins past top speed get no drive; bins the braking run skipped copy their neighbour.
	var top := int(best / ENVELOPE_STEP)
	for b in bins:
		if accel[b] <= 0.0:
			accel[b] = 0.0 if b > top else (accel[b - 1] if b > 0 else 5.0)
		if decel[b] <= 0.0:
			decel[b] = decel[b - 1] if b > 0 else 10.0
	return [accel, decel]


static func _lookup(table: PackedFloat32Array, v: float) -> float:
	var x := clampf(v / ENVELOPE_STEP, 0.0, table.size() - 1.001)
	var i := int(x)
	return lerpf(table[i], table[i + 1], x - i)
