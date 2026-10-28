class_name QualiSession
extends RefCounted
## Shortened knock-out qualifying (Q1/Q2/Q3) with every car on track. Each car starts in its
## garage; a run is the pit lane at the limiter, an out-lap, one or more timed laps from the
## line and an in-lap back to the box, as often as the clock allows. The player leaves the
## garage and asks for the pits themselves; the AI follows a seeded plan of runs (the quick
## teams go late). AI cars near the player run the full physics (traffic is real), the rest
## follow their line like in the race. A lap started before the flag may be completed.

enum Phase { RUNNING, BETWEEN, DONE }

const DURATIONS := [360.0, 300.0, 240.0]
const SESSION_NAMES := ["Q1", "Q2", "Q3"]
## Cars through to the next session after Q1 and Q2.
const CUTS := [17, 10]
const OFF_TRACK := [Surface.Type.GRASS, Surface.Type.GRAVEL, Surface.Type.RUNOFF_ASPHALT, Surface.Type.WALL]
## Out- and in-laps as a share of the AI's racing pace.
const OUT_PACE := 0.8
## Garages share the middle of the pit lane; a team's second car stops this far behind.
const BOXES_FROM := 0.25
const BOXES_TO := 0.75
const TEAMMATE_GAP := 7.0
## Parked cars sit this far toward the garages from the lane's centre.
const BOX_SIDE := 3.5

var track: LoadedTrack
var model: SeasonModel
var gp_id := ""
var level := AiSkill.PROFESSIONAL
var player_code := ""
var seed_value := 0
var durations: Array = DURATIONS
var env: TrackEnvironment
var geo: TrackGeometry
var cars: Array[QualiCar] = []
var player: QualiCar
var player_input: Callable
## Driver aids the player chose.
var assists := AssistConfig.new()
## The input actually applied last tick (haptics read it).
var last_input := DriverInput.new()

var phase := Phase.RUNNING
var session := 0
var clock := 0.0  ## seconds left in the session
var elapsed := 0.0
var eliminated_in := -1
var events: Array = []

var spec: CarSpec:
	get:
		return player.spec
var state: CarState:
	get:
		return player.state
## The player's best valid lap of each session.
var best: Array:
	get:
		return player.times
var last_lap: float:
	get:
		return player.last_lap
var on_timed_lap: bool:
	get:
		return player.run == QualiCar.Run.FLYING
	set(v):
		player.run = QualiCar.Run.FLYING if v else QualiCar.Run.OUT_LAP
var lap_start: float:
	get:
		return player.lap_start
	set(v):
		player.lap_start = v
var lap_valid: bool:
	get:
		return player.lap_valid
	set(v):
		player.lap_valid = v

var _rng := RandomNumberGenerator.new()
var _pit_length := 0.0
var _lane_heights := PackedFloat32Array()


func setup(loaded: LoadedTrack, season: SeasonModel, gp: String, ai_level: int, code: String, seed_v: int, session_durations: Array = DURATIONS) -> void:
	track = loaded
	model = season
	gp_id = gp
	level = ai_level
	player_code = code
	seed_value = seed_v
	durations = session_durations
	env = TrackEnvironment.on(loaded.data)
	geo = TrackGeometry.new(loaded.data)
	_rng.seed = seed_v + 101
	var lane := loaded.pit_lane
	_lane_heights.resize(lane.size())
	for k in lane.size():
		if k > 0:
			_pit_length += lane[k - 1].distance_to(lane[k])
		_lane_heights[k] = geo.height_at(geo.project(lane[k]))
	var team_ids: Array = model.data["teams"].map(func(t): return t["id"])
	var placed := {}
	var profiles := {}
	var starters := season.starters()
	for k in starters.size():
		var d: Dictionary = starters[k]
		var c := QualiCar.new()
		c.code = d["code"]
		c.driver = d
		c.team = season.team(d["team"])
		c.is_player = c.code == code
		c.spec = season.car_spec(d["team"], gp, not c.is_player)
		c.grid_position = k
		c.skill = season.driver_skill(c.code, level)
		c.estimate = Qualifying.estimated_lap(loaded, season, gp, d["team"], c.code, level) * Qualifying.QUALI_TRIM
		c.noise = [_rng.randfn(0.0, Qualifying.LAP_NOISE), _rng.randfn(0.0, Qualifying.LAP_NOISE), _rng.randfn(0.0, Qualifying.LAP_NOISE)]
		var ti := team_ids.find(d["team"])
		c.box_s = _pit_length * lerpf(BOXES_FROM, BOXES_TO, float(ti) / maxf(team_ids.size() - 1, 1)) - TEAMMATE_GAP * placed.get(d["team"], 0)
		placed[d["team"]] = placed.get(d["team"], 0) + 1
		if c.is_player:
			player = c
		else:
			if not profiles.has(d["team"]):
				profiles[d["team"]] = SpeedProfile.build(loaded, c.spec, &"soft")
			c.profile = profiles[d["team"]]
			c.ai = AiDriver.new(loaded, c.profile, c.skill, seed_v + k)
			c.slow_skill = c.skill.for_driver(0.0)
			c.slow_skill.pace *= OUT_PACE
		cars.append(c)
	_begin(0)


func _begin(s: int) -> void:
	session = s
	clock = durations[s]
	elapsed = 0.0
	phase = Phase.RUNNING
	var through := _ranking(s - 1).slice(0, CUTS[s - 1]) if s > 0 else Array(cars)
	var plan_rng := RandomNumberGenerator.new()
	plan_rng.seed = seed_value + 7 * s + 3
	var by_pace := Array(cars)
	by_pace.sort_custom(func(a, b): return a.estimate < b.estimate)
	for c in cars:
		c.in_session[s] = c in through
		c.state = CarState.create(c.spec, &"soft", 70.0)
		c.run = QualiCar.Run.GARAGE if c.in_session[s] else QualiCar.Run.OUT
		c.physics = c.is_player
		c.pit_requested = false
		c.drove = false
		c.lap_valid = true
		c.laps_left = 0
		c.plan_k = 0
		c.plan = [] if c.is_player or not c.in_session[s] else _plan(c, s, float(by_pace.find(c)) / cars.size(), plan_rng)
		_park(c)
	_event("%s: luz verde, %d minutos · sal del box cuando quieras" % [SESSION_NAMES[s], roundi(durations[s] / 60.0)])


## When the AI leaves its garage and for how many timed laps: the quick cars go late, when
## the track is fastest; another run only if its timed lap can still start before the flag.
func _plan(c: QualiCar, s: int, pace_rank: float, rng: RandomNumberGenerator) -> Array:
	var lap: float = c.estimate * Qualifying.EVOLUTION[s]
	var pit_out := (_pit_length - c.box_s) / RaceSession.PIT_SPEED
	var out_lap := lap / OUT_PACE
	var back := lap / OUT_PACE + c.box_s / RaceSession.PIT_SPEED
	var latest: float = durations[s] - pit_out - out_lap - 3.0
	var runs := []
	var t := 0.0
	while runs.size() < 3 and latest >= t:
		var start := t + rng.randf_range(5.0, 25.0)
		if runs.is_empty():
			var eager := rng.randf_range(0.55, 0.95) if pace_rank < 0.4 else rng.randf_range(0.0, 0.6)
			start = lerpf(0.0, latest, eager)
		start = minf(start, latest)
		var laps := 2 if start + pit_out + out_lap + lap < durations[s] - 2.0 and rng.randf() < 0.6 else 1
		runs.append({"start": start, "laps": laps})
		t = start + pit_out + out_lap + lap * laps + back + 30.0
	return runs


func step(dt: float) -> void:
	if phase != Phase.RUNNING:
		return
	elapsed += dt
	clock = maxf(0.0, clock - dt)
	var focus := player.state.position
	var physics_states: Array[CarState] = []
	var physics_specs: Array = []
	for c in cars:
		match c.run:
			QualiCar.Run.OUT:
				continue
			QualiCar.Run.GARAGE:
				if not c.is_player and c.plan_k < c.plan.size() and elapsed >= c.plan[c.plan_k]["start"] and clock > 0.0:
					c.laps_left = c.plan[c.plan_k]["laps"]
					c.plan_k += 1
					_leave(c)
				continue
			QualiCar.Run.PIT_OUT, QualiCar.Run.PIT_IN:
				_pit_step(c, dt)
				continue
		if not c.is_player:
			var want_physics := c.state.position.distance_to(focus) < RaceSession.LOD_RADIUS
			if want_physics != c.physics:
				c.switch_mode(want_physics, geo)
		var prev := c.state.track_index if c.physics else c.kin_index
		if c.is_player:
			_player_step(c, dt)
		elif c.physics:
			_ai_step(c, dt)
		else:
			var pace := 1.0 if c.run == QualiCar.Run.FLYING else OUT_PACE
			c.advance_on_line(track, c.profile.speeds[c.kin_index] * c.skill.pace * RaceSession.KIN_EFFICIENCY * pace, dt)
		if c.physics and c.on_track():
			physics_states.append(c.state)
			physics_specs.append(c.spec)
		if c.on_track():
			_progress(c, prev)
	if physics_states.size() > 1:
		CarContacts.resolve(physics_states, physics_specs)
	if clock <= 0.0 and not cars.any(func(c): return c.run == QualiCar.Run.FLYING):
		end_session()


func _player_step(c: QualiCar, dt: float) -> void:
	var raw: DriverInput = player_input.call(c.state, dt) if player_input.is_valid() else DriverInput.new()
	last_input = Assists.apply(raw, c.state, c.spec, assists)
	VehicleSim.step(c.state, c.spec, last_input, env, dt)
	check_limits()


func _ai_step(c: QualiCar, dt: float) -> void:
	c.ai.skill = c.skill if c.run == QualiCar.Run.FLYING else c.slow_skill
	c.ai.others = _nearby_states(c)
	var raw := c.ai.drive(c.state, dt)
	if c.ai.gave_up:
		c.run = QualiCar.Run.OUT  # beached: out of the session with whatever time it has
		return
	VehicleSim.step(c.state, c.spec, Assists.apply(raw, c.state, c.spec, c.ai.assists), env, dt)
	_check_limits(c)


func _nearby_states(c: QualiCar) -> Array:
	var out := []
	for o in cars:
		if o != c and o.physics and o.on_track() and o.state.position.distance_squared_to(c.state.position) < 900.0:
			out.append(o.state)
	return out


## Every wheel off the track (or a wall hit) deletes the player's timed lap.
func check_limits() -> void:
	if _check_limits(player):
		_event("Vuelta anulada: límites de pista")


func _check_limits(c: QualiCar) -> bool:
	if c.run != QualiCar.Run.FLYING or not c.lap_valid:
		return false
	var off := 0
	for w in c.state.wheels:
		if w.surface in OFF_TRACK:
			off += 1
	if off == c.state.wheels.size() or c.state.wall_contact:
		c.lap_valid = false
		return true
	return false


func _progress(c: QualiCar, prev: int) -> void:
	var idx := c.state.track_index
	if idx < 0:
		return
	var n := track.data.points.size()
	if prev > n - 30 and idx < 30:
		_crossed_line(c)
	var heading_in := c.run == QualiCar.Run.IN_LAP or (c.run == QualiCar.Run.OUT_LAP and c.pit_requested)
	if heading_in and prev < track.pit_entry_index and idx >= track.pit_entry_index and idx - prev < 20:
		c.run = QualiCar.Run.PIT_IN
		c.pit_s = 0.0
		c.physics = c.is_player


func _crossed_line(c: QualiCar) -> void:
	c.state.powertrain.reset_kers_lap()
	if c.run == QualiCar.Run.FLYING:
		var lap := elapsed - c.lap_start
		c.last_lap = lap
		c.laps_left -= 1
		if c.lap_valid:
			var t: float = lap if c.is_player else lap * Qualifying.QUALI_TRIM * Qualifying.EVOLUTION[session] * (1.0 + c.noise[session])
			if t < c.times[session]:
				c.times[session] = t
			if c.is_player:
				_event("Vuelta: %s" % RaceFormat.lap_time(lap))
	elif c.run != QualiCar.Run.OUT_LAP:
		return
	var more := not c.pit_requested if c.is_player else c.laps_left > 0
	if clock <= 0.0 or not more:
		c.run = QualiCar.Run.IN_LAP
		return
	c.run = QualiCar.Run.FLYING
	c.lap_start = elapsed
	c.lap_valid = true


# --- garage and pit lane ----------------------------------------------------------------

## The player's "leave the garage" button: down the pit lane on fresh softs.
func leave_garage() -> void:
	if player.run == QualiCar.Run.GARAGE and clock > 0.0 and phase == Phase.RUNNING:
		player.drove = true
		_leave(player)


## The player's BOXES button: in at the end of this lap (a timed lap in progress still counts).
func request_pit() -> void:
	if player.on_track():
		player.pit_requested = not player.pit_requested


func _leave(c: QualiCar) -> void:
	for w in c.state.wheels:
		w.tyre = TyreState.fresh(&"soft", 70.0)
	c.run = QualiCar.Run.PIT_OUT
	c.pit_s = c.box_s
	c.pit_requested = false


func _pit_step(c: QualiCar, dt: float) -> void:
	c.pit_s += RaceSession.PIT_SPEED * dt
	if c.run == QualiCar.Run.PIT_IN and c.pit_s >= c.box_s:
		_park(c)
		c.run = QualiCar.Run.GARAGE
		c.pit_requested = false
		return
	if c.run == QualiCar.Run.PIT_OUT and c.pit_s >= _pit_length:
		_join_track(c)
		return
	# Ease between the box (toward the garages) and the middle of the lane.
	var from_box := absf(c.pit_s - c.box_s)
	_pose_in_lane(c, c.pit_s, BOX_SIDE * clampf(1.0 - from_box / 20.0, 0.0, 1.0), RaceSession.PIT_SPEED)


func _park(c: QualiCar) -> void:
	_pose_in_lane(c, c.box_s, BOX_SIDE, 0.0)
	c.state.yaw_rate = 0.0


func _pose_in_lane(c: QualiCar, s: float, side: float, speed: float) -> void:
	var lane := track.pit_lane
	var acc := 0.0
	for k in range(1, lane.size()):
		var seg := lane[k - 1].distance_to(lane[k])
		if acc + seg >= s or k == lane.size() - 1:
			var t := clampf((s - acc) / seg, 0.0, 1.0)
			var dir := (lane[k] - lane[k - 1]).normalized()
			var right := -dir.orthogonal()  # the garages' side (TrackWorldBuilder._pit_building)
			c.state.position = lane[k - 1].lerp(lane[k], t) + right * side
			c.state.heading = dir.angle()
			c.state.velocity = dir * speed
			c.state.height = lerpf(_lane_heights[k - 1], _lane_heights[k], t)
			return
		acc += seg


func _join_track(c: QualiCar) -> void:
	var i := track.pit_exit_index
	var n := track.data.points.size()
	var tangent := (track.data.points[(i + 1) % n] - track.data.points[i]).normalized()
	c.state.position = track.data.points[i] - tangent.orthogonal() * (track.data.width_right[i] - 2.0)
	c.state.heading = tangent.angle()
	c.state.velocity = tangent * RaceSession.PIT_SPEED
	c.state.height = track.data.heights[i]
	c.state.track_index = i
	c.kin_index = i
	c.kin_t = 0.0
	c.kin_v = RaceSession.PIT_SPEED
	c.run = QualiCar.Run.OUT_LAP


# --- the session's end and results ---------------------------------------------------------

## Ends the session now (the clock ran out, or the player chose to simulate the rest). Runs
## still to come are filled with each car's estimate; a player who never left the garage
## gets theirs too, while driving without a valid lap leaves no time.
func end_session() -> void:
	if phase != Phase.RUNNING:
		return
	for c in cars:
		if not c.in_session[session]:
			continue
		var pending := c.plan_k < c.plan.size() or (not c.is_player and c.laps_left > 0 and c.run != QualiCar.Run.OUT)
		if c.is_player:
			pending = not c.drove and c.times[session] == INF
		if pending:
			c.times[session] = minf(c.times[session], _estimate(c, session))
	phase = Phase.BETWEEN
	var pos := _rank_of(player, session)
	_event("%s terminada: P%d" % [SESSION_NAMES[session], pos])
	if session < CUTS.size() and pos > CUTS[session]:
		eliminated_in = session
		phase = Phase.DONE
		_simulate_rest()
	elif session == SESSION_NAMES.size() - 1:
		phase = Phase.DONE


func start_next() -> void:
	if phase == Phase.BETWEEN:
		_begin(session + 1)


## With the player knocked out, the later sessions are settled on the estimates.
func _simulate_rest() -> void:
	for s in range(session + 1, SESSION_NAMES.size()):
		var through := _ranking(s - 1).slice(0, CUTS[s - 1])
		for c in cars:
			c.in_session[s] = c in through
			if c.in_session[s]:
				c.times[s] = _estimate(c, s)


func _estimate(c: QualiCar, s: int) -> float:
	return c.estimate * Qualifying.EVOLUTION[s] * (1.0 + c.noise[s])


## Cars that took part in session s, quickest first (no time at the back, in grid order).
func _ranking(s: int) -> Array:
	var out := Array(cars).filter(func(c): return c.in_session[s])
	out.sort_custom(func(a, b): return a.times[s] < b.times[s] or (a.times[s] == b.times[s] and a.grid_position < b.grid_position))
	return out


func _rank_of(c: QualiCar, s: int) -> int:
	return _ranking(s).find(c) + 1


func final_result() -> Qualifying:
	var q := Qualifying.new()
	var order := []
	var placed := {}
	for s in [2, 1, 0]:
		for c in _ranking(s):
			if not placed.has(c):
				placed[c] = true
				order.append(c)
	var best_q1 := INF
	for c in cars:
		best_q1 = minf(best_q1, c.times[0])
	for k in order.size():
		var c: QualiCar = order[k]
		var r := {"code": c.code, "team": c.team["id"], "position": k + 1}
		for s in 3:
			r["q%d" % (s + 1)] = c.times[s] if c.in_session[s] else INF
		r["best"] = minf(r["q1"], minf(r["q2"], r["q3"]))
		r["within_107"] = RaceRules.within_107(r["q1"], best_q1)
		q.results.append(r)
	return q


## Timing screen for the running session: [{code, team, time, where}] best first.
func live_table() -> Array:
	var rows := []
	for c in _ranking(session):
		var where := "box"
		if c.on_track():
			where = "pista"
		elif c.out_of_garage():
			where = "pit"
		rows.append({"code": c.code, "team": c.team["id"], "time": c.times[session], "where": where})
	return rows


func player_position() -> int:
	return _rank_of(player, session)


func cars_on_track() -> Array:
	return Array(cars).filter(func(c): return c.on_track())


func _event(text: String) -> void:
	events.append({"t": elapsed, "text": text})
