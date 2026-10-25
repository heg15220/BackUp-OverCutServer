class_name RaceSession
extends RefCounted
## One race: the start procedure, every car stepped at the fixed tick (one stepper for all,
## so the order of updates and car-to-car contacts are deterministic), laps and timing, DRS,
## pit stops, the mandatory compound change, mechanical failures with each team's real 2012
## rate, the safety car, and the classification.
##
## Level of detail: cars near the focus (the player, or the camera) run the full physics;
## the rest follow their racing line at the pace their physics AI is calibrated to post.

enum Phase { GRID, LIGHTS, RACING, FINISHED }

const LOD_RADIUS := 260.0
## Kinematic cars run at profile x pace x this (the driven AI's efficiency on its profile).
const KIN_EFFICIENCY := 0.95
const KIN_ACCEL := 14.0
const KIN_DECEL := 38.0
const GRID_TIME := 2.0
const LIGHT_INTERVAL := 1.0
const PIT_SPEED := 100.0 / 3.6
const SC_SPEED := 45.0
const SC_GAP := 22.0
const FINISH_GRACE_S := 150.0

var track: LoadedTrack
var geo: TrackGeometry
var model: SeasonModel
var gp_id := ""
var laps := 3
var mandatory := false
var entries: Array[RaceEntry] = []
var phase := Phase.GRID
var time := 0.0
var lights_on := 0
var lights_out_at := 0.0
var leader_finished_at := -1.0
var sc_active := false
var sc_until_lap := 0
var fastest_lap := INF
var fastest_lap_code := ""
## Messages for the HUD: {t, text}.
var events: Array = []
## Player input (CarState, dt) -> DriverInput; null means the player's car is AI-driven.
var player_input: Callable
## World position used to pick which cars run full physics (camera or player).
var focus := Vector2.ZERO

var _rng := RandomNumberGenerator.new()
var _track_length := 0.0
var _cumulative := PackedFloat32Array()
var _pit_length := 0.0
var _hold_positions := {}
var _real_laps := 58


func setup(loaded: LoadedTrack, season: SeasonModel, gp: String, race_laps: int, mandatory_stop: bool, level: int, player_code: String, seed_value: int, grid_codes: Array = []) -> void:
	track = loaded
	geo = TrackGeometry.new(loaded.data)
	model = season
	gp_id = gp
	laps = race_laps
	mandatory = mandatory_stop
	_rng.seed = seed_value
	_track_length = geo.length()
	_real_laps = loaded.laps
	var n := loaded.data.points.size()
	_cumulative.resize(n + 1)
	for i in n:
		_cumulative[i + 1] = _cumulative[i] + loaded.data.points[i].distance_to(loaded.data.points[(i + 1) % n])
	for k in range(1, loaded.pit_lane.size()):
		_pit_length += loaded.pit_lane[k - 1].distance_to(loaded.pit_lane[k])
	if grid_codes.is_empty():
		grid_codes = Qualifying.simulate(loaded, season, gp, level, seed_value, player_code).grid_codes(player_code)
	var profiles := {}
	for k in grid_codes.size():
		var code: String = grid_codes[k]
		var d := season.driver(code)
		var e := RaceEntry.new()
		e.code = code
		e.driver = d
		e.team = season.team(d["team"])
		e.is_player = code == player_code
		e.spec = season.car_spec(d["team"], gp, not e.is_player)
		var key := "%s|%s" % [d["team"], e.is_player]
		if not profiles.has(key):
			profiles[key] = SpeedProfile.build(loaded, e.spec, &"soft")
		e.profile = profiles[key]
		e.skill = season.driver_skill(code, level)
		e.ai = AiDriver.new(loaded, e.profile, e.skill, seed_value + k)
		e.grid_position = k + 1
		# Top ten start on their Q2 tyres (soft at Albert Park in 2012); the rest choose.
		e.start_compound = &"soft" if k < 10 or _rng.randf() < 0.6 else &"medium"
		e.pit_compound = &"medium" if e.start_compound == &"soft" else &"soft"
		e.state = CarState.create(e.spec, e.start_compound, 70.0)
		var slot := loaded.grid[mini(k, loaded.grid.size() - 1)]
		e.state.position = slot.position
		e.state.heading = slot.heading
		e.state.height = loaded.data.heights[slot.index]
		e.state.track_index = slot.index
		e.kin_index = slot.index
		e.lap_progress = _cumulative[slot.index]
		e.physics = true
		if mandatory:
			e.pit_plan_lap = clampi(roundi(laps * _rng.randf_range(0.35, 0.6)), 1, laps - 1)
		_hold_positions[e] = slot.position
		entries.append(e)
	var p := player_entry()
	focus = p.state.position if p != null else entries[0].state.position
	_event("Parrilla formada: %d coches" % entries.size())


func player_entry() -> RaceEntry:
	for e in entries:
		if e.is_player:
			return e
	return null


func step(dt: float) -> void:
	time += dt
	match phase:
		Phase.GRID:
			_hold_grid(dt)
			if time >= GRID_TIME:
				phase = Phase.LIGHTS
				lights_on = 0
				_event("Luces")
		Phase.LIGHTS:
			_hold_grid(dt)
			var on := clampi(int((time - GRID_TIME) / LIGHT_INTERVAL) + 1, 0, 5)
			if on != lights_on:
				lights_on = on
				if on == 5:
					lights_out_at = time + _rng.randf_range(0.4, 2.5)
			if lights_on == 5 and time >= lights_out_at:
				lights_on = 0
				phase = Phase.RACING
				_event("¡Apagado de luces!")
		Phase.RACING:
			_race_step(dt)
		Phase.FINISHED:
			pass


func _hold_grid(dt: float) -> void:
	for e in entries:
		if e.is_player and player_input.is_valid():
			var input: DriverInput = player_input.call(e.state, dt)
			var held := DriverInput.new()
			held.throttle = input.throttle
			held.brake = maxf(input.brake, 0.0)
			VehicleSim.step(e.state, e.spec, held, TrackEnvironment.on(track.data) if false else _env(), dt)
			if e.state.position.distance_to(_hold_positions[e]) > 0.6 and e.penalty_s == 0.0:
				e.penalty_s += RaceRules.JUMP_START_PENALTY_S
				_event("%s: salida anticipada, penalización de %d s" % [e.code, int(RaceRules.JUMP_START_PENALTY_S)])
		# Everybody else waits on the brakes.


func _race_step(dt: float) -> void:
	var p := player_entry()
	if p != null and p.status == RaceEntry.Status.RUNNING:
		focus = p.state.position
	var physics_states: Array[CarState] = []
	var physics_specs: Array = []
	var leader := _leader()
	var drs_open_race := leader != null and leader.laps_done + 1 >= RaceRules.DRS_FROM_LAP
	for e in entries:
		if e.status == RaceEntry.Status.RETIRED or e.status == RaceEntry.Status.FINISHED and e.state.speed() < 1.0:
			continue
		if e.status == RaceEntry.Status.PIT:
			_pit_step(e, dt)
			continue
		var want_physics := e.is_player or e.state.position.distance_to(focus) < LOD_RADIUS
		if want_physics != e.physics:
			_switch_mode(e, want_physics)
		if e.status == RaceEntry.Status.FINISHED:
			_cool_down(e, dt)
			continue
		var prev_index := e.state.track_index if e.physics else e.kin_index
		if e.physics:
			_physics_step(e, dt, drs_open_race)
			physics_states.append(e.state)
			physics_specs.append(e.spec)
		else:
			_kinematic_step(e, dt)
		_track_progress(e, prev_index)
		_check_reliability(e, dt)
	if physics_states.size() > 1:
		CarContacts.resolve(physics_states, physics_specs)
	_update_safety_car()
	_check_finish()


func _env() -> TrackEnvironment:
	if _env_cache == null:
		_env_cache = TrackEnvironment.on(track.data)
	return _env_cache

var _env_cache: TrackEnvironment


func _physics_step(e: RaceEntry, dt: float, drs_open_race: bool) -> void:
	var raw: DriverInput
	var in_zone := _in_drs_zone(e.lap_progress)
	if e.is_player and player_input.is_valid():
		raw = player_input.call(e.state, dt)
		raw.drs = raw.drs and drs_open_race and e.drs_eligible and in_zone
	else:
		e.ai.drs_allowed = drs_open_race and e.drs_eligible and in_zone
		e.ai.others = _nearby_states(e)
		if sc_active:
			e.ai.skill = _sc_skill(e)
		raw = e.ai.drive(e.state, dt)
		if sc_active:
			raw.throttle = minf(raw.throttle, clampf((SC_SPEED - e.state.speed()) * 0.2, 0.0, 1.0))
		if e.ai.gave_up:
			e.retire("Accidente", time)
			_maybe_deploy_safety_car(e)
			return
	var input := Assists.apply(raw, e.state, e.spec, e.ai.assists if not e.is_player else _player_assists)
	VehicleSim.step(e.state, e.spec, input, _env(), dt)
	if e.state.consume_impact() > 28.0 and not e.is_player:
		e.retire("Accidente", time)
		_maybe_deploy_safety_car(e)

## Driver aids chosen by the player (the scene sets them).
var _player_assists := AssistConfig.new()


func set_player_assists(cfg: AssistConfig) -> void:
	_player_assists = cfg


func _sc_skill(e: RaceEntry) -> AiSkill:
	var s := e.skill.for_driver(0.0)
	s.pace = minf(s.pace, 0.6)
	return s


func _nearby_states(e: RaceEntry) -> Array:
	var out := []
	for o in entries:
		if o != e and o.physics and o.status == RaceEntry.Status.RUNNING and o.state.position.distance_squared_to(e.state.position) < 900.0:
			out.append(o.state)
	return out


func _kinematic_step(e: RaceEntry, dt: float) -> void:
	var n := e.profile.points.size()
	var target := e.profile.speeds[e.kin_index] * e.skill.pace * KIN_EFFICIENCY
	if sc_active:
		target = minf(target, SC_SPEED)
		var ahead := _car_ahead(e)
		if ahead != null and _gap_m(ahead, e) < SC_GAP:
			target = minf(target, ahead.kin_v if not ahead.physics else ahead.state.speed())
	e.kin_v = move_toward(e.kin_v, target, (KIN_ACCEL if target > e.kin_v else KIN_DECEL) * dt)
	var travel := e.kin_v * dt
	while travel > 0.0:
		var seg := e.profile.ds[e.kin_index]
		var left := seg * (1.0 - e.kin_t)
		if travel < left:
			e.kin_t += travel / seg
			travel = 0.0
		else:
			travel -= left
			e.kin_t = 0.0
			e.kin_index = (e.kin_index + 1) % n
	var a := e.profile.points[e.kin_index]
	var b := e.profile.points[(e.kin_index + 1) % n]
	var jitter := (float(e.grid_position % 5) - 2.0) * 0.4  # cars side by side never sit on one line
	var tangent := (b - a).normalized()
	e.state.position = a.lerp(b, e.kin_t) + tangent.orthogonal() * jitter
	e.state.heading = tangent.angle()
	e.state.velocity = tangent * e.kin_v
	e.state.height = lerpf(track.data.heights[e.kin_index], track.data.heights[(e.kin_index + 1) % n], e.kin_t)
	e.state.track_index = e.kin_index
	e.state.distance_m += e.kin_v * dt


func _switch_mode(e: RaceEntry, to_physics: bool) -> void:
	e.physics = to_physics
	if to_physics:
		var tangent := (e.profile.points[(e.kin_index + 1) % e.profile.points.size()] - e.profile.points[e.kin_index]).normalized()
		e.state.velocity = tangent * e.kin_v
		e.state.yaw_rate = 0.0
		e.state.track_index = e.kin_index
	else:
		var pr := geo.project_hinted(e.state.position, maxi(e.state.track_index, 0))
		e.kin_index = pr.index
		e.kin_t = pr.t
		e.kin_v = e.state.speed()


func _track_progress(e: RaceEntry, prev_index: int) -> void:
	var idx := e.state.track_index
	if idx < 0:
		return
	var n := track.data.points.size()
	e.lap_progress = _cumulative[idx]
	if prev_index > n - 30 and idx < 30:
		_crossed_line(e)
	# DRS detection
	for z in track.drs_zones:
		var det: float = z["detection_s"]
		var before := _cumulative[prev_index] if prev_index >= 0 else 0.0
		if before < det and e.lap_progress >= det:
			var ahead := _car_ahead(e)
			e.drs_eligible = ahead != null and _gap_s(ahead, e) < RaceRules.DRS_GAP_S and not sc_active
	# Pit entry
	if e.status == RaceEntry.Status.RUNNING and _wants_pit(e) and prev_index < track.pit_entry_index and idx >= track.pit_entry_index and idx - prev_index < 20:
		e.status = RaceEntry.Status.PIT
		e.pit_s = 0.0
		e.pit_stopped = false
		e.pit_wait = _rng.randf_range(2.4, 3.6)
		e.state.velocity = Vector2.ZERO
		_event("%s entra en boxes" % e.code)


func _wants_pit(e: RaceEntry) -> bool:
	if e.is_player:
		return e.pit_requested
	return e.pit_plan_lap >= 0 and e.laps_done + 1 == e.pit_plan_lap and e.fitted.is_empty()


func _pit_step(e: RaceEntry, dt: float) -> void:
	var stop_at := _pit_length * 0.5
	if not e.pit_stopped and e.pit_s >= stop_at:
		e.pit_wait -= dt
		if e.pit_wait <= 0.0:
			e.pit_stopped = true
			var compound := e.pit_compound
			for w in e.state.wheels:
				w.tyre = TyreState.fresh(compound, 75.0)
			e.fitted.append(compound)
			e.pit_requested = false
			_event("%s: neumáticos %s" % [e.code, String(compound)])
	else:
		e.pit_s += PIT_SPEED * dt
	var pos := _pit_point(minf(e.pit_s, _pit_length))
	e.state.position = pos[0]
	e.state.heading = pos[1]
	e.state.velocity = Vector2.from_angle(pos[1]) * (0.0 if (not e.pit_stopped and e.pit_s >= stop_at) else PIT_SPEED)
	if e.pit_s >= _pit_length:
		var i := track.pit_exit_index
		var n := track.data.points.size()
		var tangent := (track.data.points[(i + 1) % n] - track.data.points[i]).normalized()
		e.state.position = track.data.points[i] - tangent.orthogonal() * (track.data.width_right[i] - 2.0)
		e.state.heading = tangent.angle()
		e.state.velocity = tangent * PIT_SPEED
		e.state.track_index = i
		e.kin_index = i
		e.kin_t = 0.0
		e.kin_v = PIT_SPEED
		e.status = RaceEntry.Status.RUNNING
		e.lap_progress = _cumulative[i]


func _pit_point(s: float) -> Array:
	var lane := track.pit_lane
	var acc := 0.0
	for k in range(1, lane.size()):
		var seg := lane[k - 1].distance_to(lane[k])
		if acc + seg >= s:
			var t := (s - acc) / seg
			return [lane[k - 1].lerp(lane[k], t), (lane[k] - lane[k - 1]).angle()]
		acc += seg
	return [lane[lane.size() - 1], (lane[lane.size() - 1] - lane[lane.size() - 2]).angle()]


func _crossed_line(e: RaceEntry) -> void:
	e.laps_done += 1
	e.state.powertrain.reset_kers_lap()
	if e.lap_start_time >= 0.0:
		e.last_lap = time - e.lap_start_time
		e.best_lap = minf(e.best_lap, e.last_lap)
		if e.last_lap < fastest_lap:
			fastest_lap = e.last_lap
			fastest_lap_code = e.code
	e.lap_start_time = time
	for w in e.state.wheels:
		w.tyre.laps += 1
	if leader_finished_at >= 0.0 or e.laps_done >= laps:
		e.status = RaceEntry.Status.FINISHED
		e.finish_time = time + e.penalty_s
		if leader_finished_at < 0.0:
			leader_finished_at = time
			_event("¡Bandera a cuadros! Gana %s" % e.code)


func _cool_down(e: RaceEntry, dt: float) -> void:
	# Slow down after the flag (kinematically, out of everyone's way).
	if e.physics:
		var input := DriverInput.new()
		input.brake = 0.3
		VehicleSim.step(e.state, e.spec, input, _env(), dt)
	else:
		e.kin_v = move_toward(e.kin_v, 0.0, 10.0 * dt)
		_kinematic_step(e, dt)


func _check_reliability(e: RaceEntry, dt: float) -> void:
	if e.status != RaceEntry.Status.RUNNING:
		return
	var rate: float = e.team.get("mechanical_dnf_rate", 0.05)
	var race_seconds := laps * 90.0
	var hazard := rate * (float(laps) / _real_laps) / maxf(race_seconds, 1.0)
	if _rng.randf() < hazard * dt:
		var reasons := ["Motor", "Caja de cambios", "Hidráulica", "Frenos", "Alternador", "Suspensión", "Presión de combustible"]
		e.retire("Avería: %s" % reasons[_rng.randi() % reasons.size()], time)
		_event("%s abandona (%s)" % [e.code, e.retire_reason])
		if e.physics:
			var pr := geo.project(e.state.position)
			var side := 1.0 if pr.lateral >= 0.0 else -1.0
			e.state.position += pr.tangent.orthogonal() * side * 9.0  # pulls off onto the run-off


func _maybe_deploy_safety_car(e: RaceEntry) -> void:
	_event("%s, accidente" % e.code)
	if laps < 4 or sc_active:
		return
	sc_active = true
	var leader := _leader()
	sc_until_lap = (leader.laps_done if leader != null else 0) + clampi(roundi(laps * 0.08), 1, 4)
	_event("COCHE DE SEGURIDAD")


func _update_safety_car() -> void:
	if not sc_active:
		return
	var leader := _leader()
	if leader != null and leader.laps_done >= sc_until_lap:
		sc_active = false
		_event("El coche de seguridad se retira: ¡carrera!")
		for e in entries:
			if not e.is_player:
				e.ai.skill = e.skill


func _check_finish() -> void:
	var running := false
	for e in entries:
		if e.status == RaceEntry.Status.RUNNING or e.status == RaceEntry.Status.PIT:
			running = true
	if not running or (leader_finished_at >= 0.0 and time - leader_finished_at > FINISH_GRACE_S):
		phase = Phase.FINISHED
		for e in entries:
			if e.status == RaceEntry.Status.RUNNING or e.status == RaceEntry.Status.PIT:
				e.status = RaceEntry.Status.FINISHED
				e.finish_time = time + e.penalty_s
		_apply_stop_rule()
		_event("Resultados oficiales")


func _apply_stop_rule() -> void:
	for e in entries:
		if e.status == RaceEntry.Status.FINISHED and not RaceRules.stop_rule_ok(e.start_compound, e.fitted, mandatory):
			e.status = RaceEntry.Status.RETIRED
			e.retire_reason = "Descalificado: no cumplió la parada obligatoria"
			_event("%s descalificado (parada obligatoria)" % e.code)


func _leader() -> RaceEntry:
	var best: RaceEntry = null
	for e in entries:
		if e.status == RaceEntry.Status.RETIRED:
			continue
		if best == null or e.progress_total(_track_length) > best.progress_total(_track_length):
			best = e
	return best


func _car_ahead(e: RaceEntry) -> RaceEntry:
	var mine := e.progress_total(_track_length)
	var best: RaceEntry = null
	var best_d := INF
	for o in entries:
		if o == e or o.status == RaceEntry.Status.RETIRED:
			continue
		var d := o.progress_total(_track_length) - mine
		if d > 0.0 and d < best_d:
			best_d = d
			best = o
	return best


func _gap_m(ahead: RaceEntry, behind: RaceEntry) -> float:
	return ahead.progress_total(_track_length) - behind.progress_total(_track_length)


func _gap_s(ahead: RaceEntry, behind: RaceEntry) -> float:
	return _gap_m(ahead, behind) / maxf(behind.state.speed(), 10.0)


func _in_drs_zone(s: float) -> bool:
	for z in track.drs_zones:
		var a: float = z["start_s"]
		var b: float = z["end_s"]
		if (a <= b and s >= a and s <= b) or (a > b and (s >= a or s <= b)):
			return true
	return false


## Positions now: finished first (laps, then time), then by distance covered; retired last.
func classification() -> Array:
	var list := entries.duplicate()
	list.sort_custom(func(a: RaceEntry, b: RaceEntry) -> bool:
		var ra := 2 if a.status == RaceEntry.Status.RETIRED else (0 if a.status == RaceEntry.Status.FINISHED else 1)
		var rb := 2 if b.status == RaceEntry.Status.RETIRED else (0 if b.status == RaceEntry.Status.FINISHED else 1)
		if a.status == RaceEntry.Status.FINISHED and b.status == RaceEntry.Status.FINISHED:
			if a.laps_done != b.laps_done:
				return a.laps_done > b.laps_done
			return a.finish_time < b.finish_time
		if ra != rb:
			return ra < rb
		return a.progress_total(_track_length) > b.progress_total(_track_length))
	return list


## Gap from the car in front, in seconds (for the HUD and the "relative").
func interval(e: RaceEntry) -> float:
	var ahead := _car_ahead(e)
	return _gap_s(ahead, e) if ahead != null else 0.0


func _event(text: String) -> void:
	events.append({"t": time, "text": text})
