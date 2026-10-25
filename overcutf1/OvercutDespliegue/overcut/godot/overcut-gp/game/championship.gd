class_name Championship
extends RefCounted
## The player's championship: who they are, the settings, the calendar position and the
## drivers' and constructors' standings. Saved locally as JSON (export codes come with the
## OverCut integration).

const SAVE_PATH := "user://championship_2012.json"
const VERSION := 1
## Simulated rounds: chance per car of a race-ending incident, and the race-long pace spread.
const INCIDENT_RATE := 0.04
const RACE_SPREAD_PCT := 0.35

var model: SeasonModel
var year := 2012
var team_id := ""
var player_code := ""
var level := AiSkill.PROFESSIONAL
var length := RaceRules.Length.LAPS_5
var assists := {"traction_control": true, "abs": true, "auto_gearbox": true, "stability_control": false}
## Overhead camera distance (OverheadCamera.height_scale).
var camera_zoom := 1.0
var round := 1
var driver_points := {}
var team_points := {}
var results: Array = []  ## [{gp, order: [codes], fastest}]


static func create(season: SeasonModel, team: String, code: String, ai_level: int, race_length: int) -> Championship:
	var c := Championship.new()
	c.model = season
	c.team_id = team
	c.player_code = code
	c.level = ai_level
	c.length = race_length
	return c


func next_gp() -> Dictionary:
	var cal: Array = model.data["calendar"]
	return cal[mini(round - 1, cal.size() - 1)]


func season_over() -> bool:
	return round > model.data["calendar"].size()


## True when the next round's circuit is built and can be driven.
func round_playable() -> bool:
	return not season_over() and bool(next_gp().get("available", false))


## A round whose circuit is not built yet: each car's race pace is its team's real
## qualifying gap at that Grand Prix plus the driver's gap to the team-mate and a race-long
## spread; each team's 2012 mechanical failure rate (plus incidents) decides the retirements.
func simulate_order(gp_id: String, seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var rows := []
	var retired := []
	for d in model.starters():
		var dnf := float(model.team(d["team"]).get("mechanical_dnf_rate", 0.05)) + INCIDENT_RATE
		if rng.randf() < dnf:
			retired.append(d["code"])
			continue
		var gap := model.team_gap_pct(d["team"], gp_id) + float(d.get("quali_vs_teammate_pct", 0.0)) + rng.randfn(0.0, RACE_SPREAD_PCT)
		rows.append([d["code"], gap])
	rows.sort_custom(func(a, b): return a[1] < b[1])
	var order := rows.map(func(r): return r[0])
	var fastest: String = order[rng.randi() % mini(5, order.size())] if not order.is_empty() else ""
	return {"order": order, "fastest": fastest, "retired": retired}


## Records a finishing order (classified codes, winner first) and moves to the next round.
func record_race(gp_id: String, order: Array, fastest_code: String) -> void:
	var table: Array = model.data["points"]
	for k in order.size():
		var code: String = order[k]
		var pts := RaceRules.points_for(k + 1, table)
		if pts == 0:
			continue
		driver_points[code] = driver_points.get(code, 0) + pts
		var team: String = model.driver(code)["team"]
		team_points[team] = team_points.get(team, 0) + pts
	results.append({"gp": gp_id, "order": order, "fastest": fastest_code})
	round += 1


## [[code, points], ...] best first; everyone on the grid appears (zero points last).
func driver_standings() -> Array:
	var rows := []
	for d in model.starters():
		rows.append([d["code"], driver_points.get(d["code"], 0)])
	rows.sort_custom(func(a, b): return a[1] > b[1] or (a[1] == b[1] and a[0] < b[0]))
	return rows


func team_standings() -> Array:
	var rows := []
	for t in model.data["teams"]:
		rows.append([t["id"], team_points.get(t["id"], 0)])
	rows.sort_custom(func(a, b): return a[1] > b[1])
	return rows


func to_dict() -> Dictionary:
	return {"version": VERSION, "year": year, "team": team_id, "driver": player_code, "level": level, "length": length,
		"assists": assists, "camera_zoom": camera_zoom, "round": round, "driver_points": driver_points, "team_points": team_points, "results": results}


func save(path := SAVE_PATH) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(to_dict()))


static func load_from(path: String, season: SeasonModel) -> Championship:
	if not FileAccess.file_exists(path):
		return null
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not d is Dictionary or int(d.get("version", 0)) != VERSION:
		return null
	var c := Championship.create(season, d["team"], d["driver"], int(d["level"]), int(d["length"]))
	c.assists = d.get("assists", c.assists)
	c.camera_zoom = float(d.get("camera_zoom", 1.0))
	c.round = int(d["round"])
	for k in d["driver_points"]:
		c.driver_points[k] = int(d["driver_points"][k])
	for k in d["team_points"]:
		c.team_points[k] = int(d["team_points"][k])
	c.results = d.get("results", [])
	return c
