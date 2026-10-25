class_name VehicleSim
## One fixed physics tick of a car, run as SUBSTEPS substeps.
##
## Tyres use a "demanded force limited by friction" model: each wheel is asked for a
## longitudinal force (drive, brake); if that exceeds the available grip the wheel
## saturates (locks or spins) and its friction opposes the slip velocity. Otherwise
## lateral force follows the Pacejka curve, shrunk by the friction ellipse. This
## avoids integrating wheel spin, which is unstable at low speed at this rate, while
## keeping lock-ups and wheelspin.
##
## Per tick (not per substep): one hinted track projection for the whole car, wheel
## surfaces, tyre grip factors, tyre heating/wear and wall collisions. These change
## slowly compared with 1/120 s; the force balance runs every substep.

const SUBSTEPS := 2
const STEER_RATE := 2.5  ## rad/s at the wheel
## Slip angles use max(|vx|, this) so low speeds stay stable.
const MIN_SLIP_SPEED := 3.0
const BUMP_LOAD := 0.25
const STOP_SPEED := 0.3
## Slip speed of a spinning wheel: max(SPIN_SLIP_MIN, |vx| * SPIN_SLIP_FRACTION).
const SPIN_SLIP_MIN := 3.0
const SPIN_SLIP_FRACTION := 0.2
## Collision circles (x offsets along the car axis) and their radius.
const COLLISION_CIRCLES := [2.2, 0.8, -0.8, -2.2]
const COLLISION_RADIUS := 0.55
const WALL_RESTITUTION := 0.2
const WALL_FRICTION := 0.4
## Share of the drive a limited-slip diff can move to the wheel with grip.
const DIFF_LOCK := 0.3
## Brake held this long at a standstill selects reverse (auto gearbox).
const REVERSE_HOLD := 0.4
const STANDSTILL := 0.5  ## m/s

static var _offsets_cache := {}


static func step(state: CarState, spec: CarSpec, input: DriverInput, env: TrackEnvironment, dt: float) -> void:
	var corners := _wheel_offsets(spec)
	var proj: TrackProjection = null
	if env.geometry != null:
		proj = env.geometry.project_hinted(state.position, state.track_index) if state.track_index >= 0 else env.geometry.project(state.position)
		state.track_index = proj.index
	var water := env.water_at(state.position)

	# Per-tick wheel inputs: surface, grip (tyre x surface), roughness, rolling resistance.
	var mu := PackedFloat64Array([0.0, 0.0, 0.0, 0.0])
	var bump := PackedFloat64Array([0.0, 0.0, 0.0, 0.0])
	var roll := PackedFloat64Array([0.0, 0.0, 0.0, 0.0])
	for i in 4:
		var w := state.wheels[i]
		if proj != null:
			var world := state.position + corners[i].rotated(state.heading)
			w.surface = env.geometry.surface_for(proj, env.geometry.lateral_at(proj, world))
		else:
			w.surface = Surface.Type.ASPHALT
		mu[i] = spec.base_mu * w.tyre.grip_factor(water) * Surface.grip(w.surface, water)
		bump[i] = Surface.bump(w.surface)
		roll[i] = Surface.rolling_resistance(w.surface)

	# Gravity along the car on a slope (small angles: sin ~ tan). Positive grade = uphill.
	var slope_force := 0.0
	if proj != null:
		state.height = env.geometry.height_at(proj)
		var grade_along := env.geometry.grade_at(proj) * state.forward().dot(proj.tangent)
		slope_force = -(spec.mass_kg + state.fuel_kg) * Units.G * grade_along

	var slip_energy := PackedFloat64Array([0.0, 0.0, 0.0, 0.0])
	var h := dt / SUBSTEPS
	for k in SUBSTEPS:
		_substep(state, spec, input, corners, mu, bump, roll, slip_energy, slope_force, h)

	for i in 4:
		state.wheels[i].tyre.update(dt, slip_energy[i] / dt, env.air_c, env.track_c, water)

	# Walls are a boundary, not a thin object, so checking once per tick cannot tunnel.
	# Re-project first: the car has moved up to a metre since the tick began.
	if proj != null:
		var after := env.geometry.project_hinted(state.position, state.track_index)
		state.track_index = after.index
		_collide_walls(state, spec, env.geometry, after)


static func _wheel_offsets(spec: CarSpec) -> Array[Vector2]:
	var key := spec.get_instance_id()
	if _offsets_cache.has(key):
		return _offsets_cache[key]
	var a := spec.cg_to_front
	var b := spec.cg_to_rear()
	var offsets: Array[Vector2] = [
		Vector2(a, -spec.track_front * 0.5), Vector2(a, spec.track_front * 0.5),
		Vector2(-b, -spec.track_rear * 0.5), Vector2(-b, spec.track_rear * 0.5),
	]
	_offsets_cache[key] = offsets
	return offsets


static func _substep(state: CarState, spec: CarSpec, input: DriverInput, corners: Array[Vector2], mu: PackedFloat64Array, bump: PackedFloat64Array, roll: PackedFloat64Array, slip_energy: PackedFloat64Array, slope_force: float, h: float) -> void:
	var pt := state.powertrain
	var mass := spec.mass_kg + state.fuel_kg
	var v_local := state.local_velocity()
	var speed := v_local.length()

	# Steering
	var target := clampf(input.steer, -1.0, 1.0) * spec.max_steer
	state.steer_angle = move_toward(state.steer_angle, target, STEER_RATE * h)

	# Gearbox, including reverse. In reverse the pedals swap: the brake pedal drives
	# the car backwards and the throttle pedal brakes it.
	_select_gear(state, input, v_local.x, h)
	var reversing := pt.gear == Powertrain.REVERSE
	var throttle := input.brake if reversing else input.throttle
	var brake := input.throttle if reversing else input.brake
	state.drs_open = input.drs and brake < 0.05 and not reversing
	pt.update_rpm(v_local.x)
	if state.auto_gearbox:
		pt.auto_shift()

	# Aero
	var q := 0.5 * Units.AIR_DENSITY * speed * speed
	var cl_a := spec.cl_a + (spec.drs_cl_a_delta if state.drs_open else 0.0)
	var cd_a := spec.cd_a + (spec.drs_cd_a_delta if state.drs_open else 0.0)
	var downforce := q * cl_a

	# Vertical loads: static + aero + load transfer from last substep's acceleration
	var l := spec.wheelbase
	var weight := mass * Units.G
	var long_transfer := mass * state.accel_local.x * spec.cg_height / l
	var front_half := (weight * spec.cg_to_rear() / l + downforce * spec.aero_balance_front - long_transfer) * 0.5
	var rear_half := (weight * spec.cg_to_front / l + downforce * (1.0 - spec.aero_balance_front) + long_transfer) * 0.5
	# Positive accel_local.y is towards the right, so load moves to the left wheels.
	var lat_front := mass * state.accel_local.y * spec.cg_height / spec.track_front * 0.5
	var lat_rear := mass * state.accel_local.y * spec.cg_height / spec.track_rear * 0.5

	# Longitudinal demands
	# Stopped with the brake on, the clutch is held open (as on the grid): the engine
	# revs but does not drive. Releasing the brake is the launch.
	var clutch_open := absf(v_local.x) < STANDSTILL and brake > 0.5
	var drive := 0.0 if clutch_open else pt.drive_force(throttle, input.kers, h) * (-1.0 if reversing else 1.0)
	var brake_total := clampf(brake, 0.0, 1.0) * spec.max_brake_force_n
	var stop_k := mass * 0.25 / h  # force that would stop a quarter-car in one substep

	# Loads and available grip first: the differential needs both rears' grip.
	var loads := PackedFloat64Array([0.0, 0.0, 0.0, 0.0])
	var avails := PackedFloat64Array([0.0, 0.0, 0.0, 0.0])
	for i in 4:
		var base_load: float
		if i < 2:
			base_load = front_half + (lat_front if i == CarState.FL else -lat_front)
		else:
			base_load = rear_half + (lat_rear if i == CarState.RL else -lat_rear)
		loads[i] = maxf(0.0, base_load * (1.0 + BUMP_LOAD * bump[i] * sin(state.distance_m * 1.7 + i)))
		avails[i] = TyreModel.effective_mu(mu[i], loads[i]) * loads[i]

	# Limited-slip diff: equal split, but up to DIFF_LOCK of the drive moves from a
	# wheel that cannot use its half to the other one.
	var drive_rl := drive * 0.5
	var drive_rr := drive * 0.5
	var half := absf(drive) * 0.5
	if half > avails[CarState.RL] and half <= avails[CarState.RR]:
		var moved := signf(drive) * minf(half - avails[CarState.RL], DIFF_LOCK * absf(drive))
		drive_rl -= moved
		drive_rr += moved
	elif half > avails[CarState.RR] and half <= avails[CarState.RL]:
		var moved := signf(drive) * minf(half - avails[CarState.RR], DIFF_LOCK * absf(drive))
		drive_rr -= moved
		drive_rl += moved

	var force := Vector2.ZERO
	var torque := 0.0
	for i in 4:
		var w := state.wheels[i]
		var front := i < 2
		var r: Vector2 = corners[i]
		var load := loads[i]
		w.load_n = load
		var delta := state.steer_angle if front else 0.0
		# Contact patch velocity in the car frame, then in the wheel frame.
		var vw := Vector2(v_local.x - state.yaw_rate * r.y, v_local.y + state.yaw_rate * r.x).rotated(-delta)

		var avail := avails[i]
		var brake_i := brake_total * (spec.brake_bias_front if front else 1.0 - spec.brake_bias_front) * 0.5
		var drive_i := 0.0 if front else (drive_rl if i == CarState.RL else drive_rr)
		# The brake resists the net demand: at a standstill it holds the drive back
		# (revving on the grid) instead of only opposing motion.
		var fx := drive_i - clampf(vw.x * stop_k + drive_i, -brake_i, brake_i)

		var slip_angle := atan2(vw.y, maxf(absf(vw.x), MIN_SLIP_SPEED))
		var fy: float
		var sliding := absf(fx) > avail
		if sliding:
			# A sliding tyre's friction opposes its slip velocity. Locked: the patch slides
			# at the contact velocity, so steering does nothing. Spinning: the patch slides
			# mostly backwards, leaving little for cornering.
			var slip_vel := vw if fx * vw.x < 0.0 else Vector2(-signf(fx) * maxf(SPIN_SLIP_MIN, absf(vw.x) * SPIN_SLIP_FRACTION), vw.y)
			var f_slide := -slip_vel.normalized() * avail * TyreModel.SLIDE_FACTOR if slip_vel.length() > 0.01 else Vector2(signf(fx) * avail * TyreModel.SLIDE_FACTOR, 0.0)
			fx = f_slide.x
			fy = f_slide.y
		else:
			var usage := 0.0 if avail <= 0.0 else fx / avail
			fy = -TyreModel.lateral_with_peak(slip_angle, avail) * sqrt(maxf(0.0, 1.0 - usage * usage))
		w.sliding = sliding
		w.avail_n = avail
		w.slip_angle = slip_angle
		w.slip_ratio = signf(fx) if sliding else (0.0 if avail <= 0.0 else fx / avail * TyreModel.PEAK_SLIP_RATIO)
		w.fx = fx
		w.fy = fy

		# Sliding energy for heat and wear (applied once per tick).
		var slide_speed := absf(vw.y) + (absf(vw.x) * 0.15 if sliding else absf(vw.x) * absf(w.slip_ratio))
		slip_energy[i] += (absf(fx) + absf(fy)) * slide_speed * h

		# Rolling resistance is the surface deforming (gravel, grass), not tyre friction,
		# so it is not limited by the available grip.
		var roll_i := roll[i] * load
		var f_car := Vector2(fx - clampf(vw.x * stop_k, -roll_i, roll_i), fy).rotated(delta)
		force += f_car
		torque += r.x * f_car.y - r.y * f_car.x

	# Aero drag opposes the velocity; gravity pulls along the slope.
	if speed > 0.01:
		force -= v_local / speed * q * cd_a
	force.x += slope_force

	# Integrate (semi-implicit Euler) in the world frame.
	state.accel_local = force / mass
	state.velocity += (force / mass).rotated(state.heading) * h
	state.yaw_rate += torque / spec.yaw_inertia * h
	state.heading = wrapf(state.heading + state.yaw_rate * h, -PI, PI)
	state.position += state.velocity * h
	state.distance_m += state.velocity.length() * h

	# Hold still: below STOP_SPEED with no throttle the car is parked.
	if state.velocity.length() < STOP_SPEED and throttle < 0.05:
		state.velocity = Vector2.ZERO
		state.yaw_rate = 0.0
		state.accel_local = Vector2.ZERO


## Reverse in and out. Auto: holding the brake at a standstill selects reverse,
## throttle selects first again. Manual: shift down from first at a standstill.
static func _select_gear(state: CarState, input: DriverInput, vx: float, h: float) -> void:
	var pt := state.powertrain
	var stopped := absf(vx) < STANDSTILL
	if pt.gear == Powertrain.REVERSE:
		state.reverse_hold = 0.0
		if (state.auto_gearbox and input.throttle > 0.3 and vx > -STANDSTILL) or (not state.auto_gearbox and input.shift_up):
			pt.select_first()
		return
	if state.auto_gearbox:
		if pt.gear == 1 and stopped and input.brake > 0.3 and input.throttle < 0.05:
			state.reverse_hold += h
			if state.reverse_hold >= REVERSE_HOLD:
				state.reverse_hold = 0.0
				pt.select_reverse()
		else:
			state.reverse_hold = 0.0
		return
	if input.shift_down and pt.gear == 1 and stopped:
		pt.select_reverse()
	elif input.shift_up:
		pt.shift(1)
	elif input.shift_down:
		pt.shift(-1)


## Four circles along the car's axis against the track walls: positional correction
## plus an impulse with restitution and wall friction at the contact point.
static func _collide_walls(state: CarState, spec: CarSpec, geo: TrackGeometry, proj: TrackProjection) -> void:
	state.wall_contact = false
	var mass := spec.mass_kg + state.fuel_kg
	for x in COLLISION_CIRCLES:
		var r := Vector2(x, 0.0).rotated(state.heading)
		var lateral := geo.lateral_at(proj, state.position + r)
		var depth := geo.wall_penetration(proj, lateral, COLLISION_RADIUS)
		if depth <= 0.0:
			continue
		state.wall_contact = true
		var n := geo.inward_normal(proj, lateral)
		state.position += n * depth
		var v_point := state.velocity + r.rotated(PI / 2) * state.yaw_rate
		var vn := v_point.dot(n)
		if vn >= 0.0:
			continue
		state.last_impact_speed = maxf(state.last_impact_speed, -vn)
		var rn := r.x * n.y - r.y * n.x
		var j := -(1.0 + WALL_RESTITUTION) * vn / (1.0 / mass + rn * rn / spec.yaw_inertia)
		var tangent_v := v_point - n * vn
		var impulse := n * j
		if tangent_v.length() > 0.01:
			var t := tangent_v.normalized()
			var rt := r.x * t.y - r.y * t.x
			var jt := minf(WALL_FRICTION * j, tangent_v.length() / (1.0 / mass + rt * rt / spec.yaw_inertia))
			impulse -= t * jt
		state.velocity += impulse / mass
		state.yaw_rate += (r.x * impulse.y - r.y * impulse.x) / spec.yaw_inertia
