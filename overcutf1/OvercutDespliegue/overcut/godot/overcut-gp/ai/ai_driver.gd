class_name AiDriver
extends RefCounted
## An AI racing driver: follows the racing line with pure pursuit, holds the speed profile
## scaled by its skill, moves off the line to pass or defend, uses KERS and DRS, and
## reverses away from walls when stuck. It only ever produces a DriverInput.

const WHEELBASE := 3.4
const YAW_DAMPING := 1.2
## Body slip angle (rad) where the driver starts catching a slide, and the extra angle
## over which the correction becomes total.
const SLIDE_START := 0.05
const SLIDE_FULL := 0.10
const STUCK_SPEED := 1.5
const STUCK_TIME := 1.2
const REVERSE_TIME := 1.6
const STUCK_GIVE_UP := 3.0  ## stopped this long anywhere: try reversing
const MAX_RECOVERIES := 3  ## after this many failed attempts the car is out (beached)

var track: LoadedTrack
var profile: SpeedProfile
var skill: AiSkill
var geo: TrackGeometry
var assists := AssistConfig.new()
## Driving style constants (tuned with tests/bench/ai_tune.gd).
var brake_lookahead_s := 0.3  ## how far ahead (in time) the driver reads the speed profile
var brake_release := 2.2  ## how quickly the brake comes off as steering goes in
var throttle_feed := 1.25  ## throttle allowed = feed - rear lateral usage
var brake_gain := 0.9  ## pedal per m/s above the target speed
## Lateral offset from the racing line (m, + = left), eased toward _target_offset.
var lateral_offset := 0.0
## Whether race control allows DRS for this car right now (set by the session).
var drs_allowed := false
## Other cars on track (set by the session) for passing and defending.
var others: Array = []

## True once the car could not get going again (beached in gravel); the session retires it.
var gave_up := false
## The last input the car actually received (telemetry).
var last_input := DriverInput.new()
## Last pure-pursuit numbers (telemetry / debugging).
var debug_alpha := 0.0
var debug_target := Vector2.ZERO
var _recoveries := 0
var _target_offset := 0.0
var _stuck := 0.0
var _reversing := 0.0
var _mistake_until := -1
var _rng := RandomNumberGenerator.new()


func _init(loaded: LoadedTrack, speed_profile: SpeedProfile, ai_skill: AiSkill, seed_value := 0) -> void:
	track = loaded
	profile = speed_profile
	skill = ai_skill
	geo = TrackGeometry.new(loaded.data)
	assists.traction_control = true
	assists.abs = true
	assists.stability_control = true
	_rng.seed = seed_value


func drive(state: CarState, dt: float) -> DriverInput:
	var input := DriverInput.new()
	var proj := geo.project_hinted(state.position, state.track_index) if state.track_index >= 0 else geo.project(state.position)
	var n := profile.points.size()
	var i := proj.index
	var v := state.speed()

	# Recovery: stuck against something -> back off in reverse, steering away.
	if _reversing > 0.0:
		_reversing -= dt
		input.brake = 1.0  # held at a standstill this selects reverse; then it drives backwards
		var err := angle_difference(state.heading, proj.tangent.angle())
		input.steer = clampf(-err * 1.5, -1.0, 1.0)
		return input
	var heading_err := angle_difference(state.heading, proj.tangent.angle())
	if v < STUCK_SPEED and state.powertrain.gear != Powertrain.REVERSE:
		_stuck += dt
		var blocked := state.wall_contact or absf(heading_err) > 0.9
		if (_stuck > STUCK_TIME and blocked) or _stuck > STUCK_GIVE_UP:
			_stuck = 0.0
			_recoveries += 1
			if _recoveries > MAX_RECOVERIES:
				gave_up = true
			_reversing = REVERSE_TIME
	else:
		_stuck = 0.0
		if v > 15.0:
			_recoveries = 0

	_plan_offset(state, proj)
	lateral_offset = move_toward(lateral_offset, _target_offset, 3.0 * dt)

	# Steering: pure pursuit on a point of the (offset) line ahead.
	# Long look-ahead keeps the car calm at speed; in a tight corner it would cut the apex,
	# so it shrinks with the curvature just ahead.
	var look := 8.0 + v * 0.55
	var kappa_ahead := maxf(profile.curvature[(i + 2) % n], profile.curvature[(i + 4) % n])
	look = minf(look, 7.0 + 0.9 / maxf(kappa_ahead, 0.002) * 0.12)
	var k := (i + maxi(1, roundi(look / 5.0))) % n
	var nrm := (track.data.points[(k + 1) % n] - track.data.points[(k - 1 + n) % n]).normalized().orthogonal()
	var target := profile.points[k] + nrm * lateral_offset
	var local := (target - state.position).rotated(-state.heading)  # car frame: x forward, y right
	var alpha := atan2(local.y, local.x)  # positive = target to the right
	debug_alpha = alpha
	debug_target = target
	var dist := maxf(local.length(), 1.0)
	var delta := atan(2.0 * WHEELBASE * sin(alpha) / dist)
	# Yaw damping: pure pursuit asks for a yaw rate of 2 v sin(alpha) / Ld; steer against any
	# excess so the loop does not ring at high speed.
	var wanted_yaw := 2.0 * v * sin(alpha) / dist
	delta -= YAW_DAMPING * (state.yaw_rate - wanted_yaw) * WHEELBASE / maxf(v, 5.0)
	# Catching a slide: when the car's body angle to its path grows, steer into the slide
	# (toward where the car is actually going) and come off the brake.
	var v_local := state.local_velocity()
	var beta := atan2(v_local.y, maxf(absf(v_local.x), 1.0))  # + = moving to the right of the nose
	var catch := clampf((absf(beta) - SLIDE_START) / SLIDE_FULL, 0.0, 1.0)
	delta = lerpf(delta, beta * 1.2, catch)
	input.steer = clampf(delta / 0.30, -1.0, 1.0)

	# Speed: the profile a little ahead (reaction + the level's braking margin).
	var ahead := (i + maxi(1, roundi((v * brake_lookahead_s + skill.brake_margin) / 5.0))) % n
	var target_v := minf(profile.speeds[ahead], profile.speeds[(ahead + 1) % n]) * skill.pace
	if _mistake_until >= 0:
		target_v *= 1.08  # carried too much speed into this corner
		if i == _mistake_until:
			_mistake_until = -1
	elif profile.curvature[ahead] > 0.02 and _rng.randf() < skill.mistake_rate * dt * 0.05:
		_mistake_until = (ahead + 6) % n
	var err_v := target_v - v
	# Racing drivers brake hard and late, not gently: a small proportional band either side.
	# Below target the car is on the profile's acceleration limit: go flat out. A small
	# dead band above target coasts instead of dabbing the brake.
	if err_v >= -0.4:
		input.throttle = clampf(0.6 + err_v * 1.5, 0.0, 1.0)
		# Feed the throttle in as the rear tyres unwind from the corner.
		var rl := state.wheels[CarState.RL]
		var rr := state.wheels[CarState.RR]
		var rear_lat := maxf(absf(rl.fy) / maxf(rl.avail_n, 1.0), absf(rr.fy) / maxf(rr.avail_n, 1.0))
		input.throttle = minf(input.throttle, clampf(throttle_feed - rear_lat, 0.15, 1.0))
	else:
		input.brake = clampf((-err_v - 0.4) * brake_gain, 0.0, 1.0)
		# Trail braking: release the pedal as the steering goes in.
		# Trail braking: only as much pedal as the front tyres have left after cornering.
		var fl := state.wheels[CarState.FL]
		var fr := state.wheels[CarState.FR]
		var front_lat := maxf(absf(fl.fy) / maxf(fl.avail_n, 1.0), absf(fr.fy) / maxf(fr.avail_n, 1.0))
		input.brake = minf(input.brake, clampf(1.0 + brake_release * 0.25 - front_lat * brake_release * 0.5, 0.0, 1.0))
		input.brake *= 1.0 - catch
	var straight := profile.curvature[ahead] < 0.004
	input.kers = straight and input.throttle >= 0.99 and v < 82.0
	input.drs = drs_allowed and straight and input.brake == 0.0
	last_input = input
	return input


## Moves off the racing line to pass a slower car ahead, or covers the inside when attacked.
func _plan_offset(state: CarState, proj: TrackProjection) -> void:
	_target_offset = 0.0
	var fwd := state.forward()
	for other in others:
		var o: CarState = other
		if o == state:
			continue
		var rel := o.position - state.position
		var along := rel.dot(fwd)
		var side := rel.dot(fwd.orthogonal())  # + = left
		if along > 0.0 and along < 18.0 + state.speed() * 0.3 and absf(side) < 2.6:
			# a car ahead on our line and we are faster: pick the side with more room
			if state.speed() > o.speed() + 0.5 * (1.0 - skill.aggression):
				var room_left := track.data.width_left[proj.index] - track.racing_line[proj.index]
				var room_right := track.data.width_right[proj.index] + track.racing_line[proj.index]
				_target_offset = 2.8 if room_left > room_right else -2.8
				return
