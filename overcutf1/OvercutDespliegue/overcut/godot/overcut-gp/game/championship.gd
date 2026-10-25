class_name Championship
extends RefCounted
## The player's championship: who they are, the settings, the calendar position and the
## drivers' and constructors' standings. Saved locally as JSON (export codes come with the
## OverCut integration).

const SAVE_PATH := "user://championship_2012.json"
const VERSION := 1

var model: SeasonModel
var year := 2012
var team_id := ""
var player_code := ""
var level := AiSkill.PROFESSIONAL
var length := RaceRules.Length.LAPS_5
var assists := {"traction_control": true, "abs": true, "auto_gearbox": true, "stability_control": false}
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
		"assists": assists, "round": round, "driver_points": driver_points, "team_points": team_points, "results": results}


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
	c.round = int(d["round"])
	for k in d["driver_points"]:
		c.driver_points[k] = int(d["driver_points"][k])
	for k in d["team_points"]:
		c.team_points[k] = int(d["team_points"][k])
	c.results = d.get("results", [])
	return c
