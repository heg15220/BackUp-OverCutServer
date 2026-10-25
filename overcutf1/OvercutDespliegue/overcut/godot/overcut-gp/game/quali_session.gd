class_name QualiSession
extends RefCounted
## Shortened knock-out qualifying with the player driving: Q1/Q2/Q3 against the clock
## (lap times of the AI come from Qualifying.simulate and appear on the timing screen during
## the session), an out-lap from the pit exit, timed laps from the line, laps deleted for
## leaving the track, and a lap started before the flag may be completed.

enum Phase { RUNNING, BETWEEN, DONE }

const DURATIONS := [360.0, 300.0, 240.0]
const SESSION_NAMES := ["Q1", "Q2", "Q3"]
## Cars through to the next session after Q1 and Q2.
const CUTS := [17, 10]
const OFF_TRACK := [Surface.Type.GRASS, Surface.Type.GRAVEL, Surface.Type.RUNOFF_ASPHALT, Surface.Type.WALL]
const PIT_EXIT_SPEED := 22.0

var track: LoadedTrack
var model: SeasonModel
var gp_id := ""
var level := AiSkill.PROFESSIONAL
var player_code := ""
var seed_value := 0
var durations: Array = DURATIONS
var spec: CarSpec
var state: CarState
var env: TrackEnvironment
var player_input: Callable
## Driver aids the player chose.
var assists := AssistConfig.new()
## The input actually applied last tick (haptics read it).
var last_input := DriverInput.new()

var phase := Phase.RUNNING
var session := 0
var clock := 0.0  ## seconds left in the session
var best := [INF, INF, INF]
var drove := [false, false, false]
var last_lap := 0.0
var on_timed_lap := false
var lap_start := 0.0
var lap_valid := true
var elapsed := 0.0
var eliminated_in := -1
var events: Array = []

var _player_times := {}
var _reveal := {}  ## code -> [fraction of each session when its lap appears]
var _table_cache: Qualifying


func setup(loaded: LoadedTrack, season: SeasonModel, gp: String, ai_level: int, code: String, seed_v: int, session_durations: Array = DURATIONS) -> void:
	track = loaded
	model = season
	gp_id = gp
	level = ai_level
	player_code = code
	seed_value = seed_v
	durations = session_durations
	env = TrackEnvironment.on(loaded.data)
	spec = season.car_spec(season.driver(code)["team"], gp, false)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v + 101
	for d in season.starters():
		_reveal[d["code"]] = [rng.randf_range(0.3, 0.97), rng.randf_range(0.3, 0.97), rng.randf_range(0.3, 0.97)]
	_begin(0)


func _begin(s: int) -> void:
	session = s
	clock = durations[s]
	elapsed = 0.0
	phase = Phase.RUNNING
	on_timed_lap = false
	lap_valid = true
	state = CarState.create(spec, &"soft", 70.0)
	var i := track.pit_exit_index
	var n := track.data.points.size()
	var tangent := (track.data.points[(i + 1) % n] - track.data.points[i]).normalized()
	state.position = track.data.points[i] - tangent.orthogonal() * (track.data.width_right[i] - 2.0)
	state.heading = tangent.angle()
	state.velocity = tangent * PIT_EXIT_SPEED
	state.height = track.data.heights[i]
	state.track_index = i
	_table_cache = null
	_event("%s: luz verde, %d minutos" % [SESSION_NAMES[s], roundi(durations[s] / 60.0)])


func step(dt: float) -> void:
	if phase != Phase.RUNNING:
		return
	elapsed += dt
	clock = maxf(0.0, clock - dt)
	var prev := state.track_index
	var raw: DriverInput = player_input.call(state, dt) if player_input.is_valid() else DriverInput.new()
	last_input = Assists.apply(raw, state, spec, assists)
	VehicleSim.step(state, spec, last_input, env, dt)
	if raw.throttle > 0.0 or raw.brake > 0.0:
		drove[session] = true
	check_limits()
	var n := track.data.points.size()
	if prev > n - 30 and state.track_index >= 0 and state.track_index < 30:
		_crossed_line()
	if clock <= 0.0 and not on_timed_lap:
		end_session()


## Every wheel off the track (or a wall hit) deletes the lap.
func check_limits() -> void:
	if not on_timed_lap or not lap_valid:
		return
	var off := 0
	for w in state.wheels:
		if w.surface in OFF_TRACK:
			off += 1
	if off == state.wheels.size() or state.wall_contact:
		lap_valid = false
		_event("Vuelta anulada: límites de pista")


func _crossed_line() -> void:
	state.powertrain.reset_kers_lap()
	if on_timed_lap:
		last_lap = elapsed - lap_start
		if lap_valid:
			if last_lap < best[session]:
				best[session] = last_lap
				_player_times[session] = last_lap
				_table_cache = null
			_event("Vuelta: %s" % RaceFormat.lap_time(last_lap))
	if clock <= 0.0:
		on_timed_lap = false
		end_session()
		return
	on_timed_lap = true
	lap_start = elapsed
	lap_valid = true


## Ends the session now (the clock ran out, or the player chose to simulate the rest).
## Without any driving the player's lap is the estimate for their car; driving without a
## valid lap leaves no time.
func end_session() -> void:
	if phase != Phase.RUNNING:
		return
	if best[session] < INF:
		_player_times[session] = best[session]
	elif drove[session]:
		_player_times[session] = INF
	phase = Phase.BETWEEN
	_table_cache = null
	var q := _simulated()
	var pos := _session_rank(q, session)
	_event("%s terminada: P%d" % [SESSION_NAMES[session], pos])
	if session < CUTS.size() and pos > CUTS[session]:
		eliminated_in = session
		phase = Phase.DONE
	elif session == SESSION_NAMES.size() - 1:
		phase = Phase.DONE


func start_next() -> void:
	if phase == Phase.BETWEEN:
		_begin(session + 1)


func final_result() -> Qualifying:
	return _simulated()


## Timing screen for the running session: [{code, team, time}] best first; AI laps appear
## as the session goes on, the player's best as soon as it is set.
func live_table() -> Array:
	var q := _simulated()
	var key := "q%d" % (session + 1)
	var frac: float = 1.0 if phase != Phase.RUNNING else elapsed / float(durations[session])
	var rows := []
	for r in q.results:
		var t: float = r[key]
		if r["code"] == player_code:
			t = best[session]
		elif frac < _reveal[r["code"]][session]:
			t = INF
		if not _in_session(q, r, session):
			continue
		rows.append({"code": r["code"], "team": r["team"], "time": t})
	rows.sort_custom(func(a, b): return a["time"] < b["time"])
	return rows


func player_position() -> int:
	var rows := live_table()
	for k in rows.size():
		if rows[k]["code"] == player_code:
			return k + 1
	return rows.size()


func _simulated() -> Qualifying:
	if _table_cache == null:
		var times := _player_times.duplicate()
		# While the session runs, the player's time is what they have set (none yet = no time).
		if phase == Phase.RUNNING and not times.has(session):
			times[session] = INF
		_table_cache = Qualifying.simulate(track, model, gp_id, level, seed_value, player_code, times)
	return _table_cache


## Cars that take part in a session: everyone in Q1, the top 17 of Q1 in Q2, the top 10 of Q2 in Q3.
func _in_session(q: Qualifying, r: Dictionary, s: int) -> bool:
	if s == 0:
		return true
	return r["q%d" % s] < INF and _session_rank(q, s - 1, r["code"]) <= CUTS[s - 1]


func _session_rank(q: Qualifying, s: int, code := "") -> int:
	if code == "":
		code = player_code
	var key := "q%d" % (s + 1)
	var mine := INF
	for r in q.results:
		if r["code"] == code:
			mine = r[key]
	var rank := 1
	for r in q.results:
		if r["code"] != code and r[key] < mine:
			rank += 1
	if mine == INF:
		rank = 0
		for r in q.results:
			if r[key] < INF or r["code"] == code:
				rank += 1
	return rank


func _event(text: String) -> void:
	events.append({"t": elapsed, "text": text})
