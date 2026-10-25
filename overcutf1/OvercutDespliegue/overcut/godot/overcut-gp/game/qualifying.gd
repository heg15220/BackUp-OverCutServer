class_name Qualifying
extends RefCounted
## Knock-out qualifying (Q1 24 -> 17, Q2 17 -> 10, Q3 top ten) with the 107 % rule.
## AI lap times come from each car's measured speed profile and the driver's skill, scaled by
## the same AI efficiency the on-track AI shows (so a simulated lap matches a driven one),
## with low-fuel and free-DRS qualifying trim and session-to-session track evolution.
## The player's own laps (when driven) replace their estimate via set_player_time().

## Ratio of an AI's driven lap to (profile lap / pace), measured on Albert Park.
const AI_EFFICIENCY := 1.052
## Qualifying trim: low fuel and DRS free in the zones (2012), as a fraction of the lap.
const QUALI_TRIM := 0.988
## Track evolution: each session is this much slower than the next.
const EVOLUTION := [1.004, 1.0015, 1.0]
const LAP_NOISE := 0.0022

var results: Array = []  ## dicts {code, team, q1, q2, q3, best, position, within_107}

static var _lap_cache := {}


static func estimated_lap(track: LoadedTrack, model: SeasonModel, gp_id: String, team_id: String, code: String, level: int) -> float:
	var spec := model.car_spec(team_id, gp_id, true)
	var key := "%s|%s|%.5f|%.5f" % [track.name, team_id, spec.base_mu, spec.cl_a]
	if not _lap_cache.has(key):
		var p := SpeedProfile.build(track, spec, &"soft")
		var t := 0.0
		for i in p.speeds.size():
			t += p.ds[i] / p.speeds[i]
		_lap_cache[key] = t
	var skill := model.driver_skill(code, level)
	return _lap_cache[key] / skill.pace * AI_EFFICIENCY


static func simulate(track: LoadedTrack, model: SeasonModel, gp_id: String, level: int, seed_value: int, player_code := "", player_times := {}) -> Qualifying:
	var q := Qualifying.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var rows := []
	for d in model.starters():
		var base := estimated_lap(track, model, gp_id, d["team"], d["code"], level) * QUALI_TRIM
		# Every car's lap noise is drawn up front, so the AI times do not depend on the
		# player's laps (the live timing screen re-runs this as the player improves).
		var noise := [rng.randfn(0.0, LAP_NOISE), rng.randfn(0.0, LAP_NOISE), rng.randfn(0.0, LAP_NOISE)]
		var row := {"code": d["code"], "team": d["team"], "base": base, "noise": noise, "q1": INF, "q2": INF, "q3": INF}
		rows.append(row)
	var session_time := func(row: Dictionary, session: int) -> float:
		if row["code"] == player_code and player_times.has(session):
			return player_times[session]
		return row["base"] * EVOLUTION[session] * (1.0 + row["noise"][session])
	for row in rows:
		row["q1"] = session_time.call(row, 0)
	rows.sort_custom(func(a, b): return a["q1"] < b["q1"])
	var best_q1: float = rows[0]["q1"]
	for k in rows.size():
		if k < 17:
			rows[k]["q2"] = session_time.call(rows[k], 1)
	var q2_rows := rows.slice(0, 17)
	q2_rows.sort_custom(func(a, b): return a["q2"] < b["q2"])
	for k in q2_rows.size():
		if k < 10:
			q2_rows[k]["q3"] = session_time.call(q2_rows[k], 2)
	var top10 := q2_rows.slice(0, 10)
	top10.sort_custom(func(a, b): return a["q3"] < b["q3"])
	var order := top10 + q2_rows.slice(10) + rows.slice(17)
	for k in order.size():
		var r: Dictionary = order[k]
		r["position"] = k + 1
		r["best"] = minf(r["q1"], minf(r["q2"], r["q3"]))
		r["within_107"] = RaceRules.within_107(r["q1"], best_q1)
	q.results = order
	return q


## Grid order: everyone who made the 107 % cut, in qualifying order (the player is
## allowed to start from the back even outside it, as stewards did in 2012).
func grid_codes(player_code := "") -> Array:
	var out := []
	var late := []
	for r in results:
		if r["within_107"]:
			out.append(r["code"])
		elif r["code"] == player_code:
			late.append(r["code"])
	return out + late
