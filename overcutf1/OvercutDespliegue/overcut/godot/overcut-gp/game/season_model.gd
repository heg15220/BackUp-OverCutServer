class_name SeasonModel
extends RefCounted
## Turns a season's real data (data/seasons/YEAR.json) into cars and drivers.
##
## Car pace: each team's qualifying gap to the fastest team at that Grand Prix (f1db) is
## reproduced by scaling grip and downforce. The lap time on the measured speed profile
## follows lap ~ f^-LAP_EXPONENT (measured on Albert Park: 87.66 s at f = 1, 80.96 s at 1.2,
## 76.66 s at 1.35), so f = (1 + gap)^(-1 / LAP_EXPONENT).
## Driver pace: the median qualifying gap to the team-mate over the season (the only
## car-neutral number) shifts the AI driver's share of the speed profile.
## AI compensation: the AI drives the same physics but only extracts ~85 % of the ideal lap
## without crashing, so AI cars get AI_GRIP_COMPENSATION on grip and downforce to post the
## real lap times. The player's car keeps the plain physics.

const LAP_EXPONENT := 0.436
const AI_GRIP_COMPENSATION := 1.38
## How much of a driver's qualifying gap to the team-mate becomes AI pace.
const DRIVER_WEIGHT := 1.0

var data: Dictionary


static func load_2012() -> SeasonModel:
	var m := SeasonModel.new()
	m.data = JSON.parse_string(FileAccess.get_file_as_string("res://data/seasons/2012.json"))
	return m


func team(team_id: String) -> Dictionary:
	for t in data["teams"]:
		if t["id"] == team_id:
			return t
	return {}


func driver(code: String) -> Dictionary:
	for d in data["drivers"]:
		if d["code"] == code:
			return d
	return {}


func starters() -> Array:
	return data["drivers"].filter(func(d): return d["starter"])


## Qualifying gap of a team to the fastest one at a Grand Prix, in percent (0 = fastest).
func team_gap_pct(team_id: String, gp_id: String) -> float:
	var pace: Dictionary = data["pace"].get(gp_id, {})
	return float(pace.get(team_id, 0.0))


func car_spec(team_id: String, gp_id: String, for_ai: bool) -> CarSpec:
	var spec := CarSpec.baseline_2012()
	var t := team(team_id)
	if not t.is_empty():
		spec.wheelbase = float(t["car"]["wheelbase"])
		spec.cg_to_front = spec.wheelbase * CarModel2012.CG_FROM_FRONT
	var f := pow(1.0 + team_gap_pct(team_id, gp_id) / 100.0, -1.0 / LAP_EXPONENT)
	if for_ai:
		f *= AI_GRIP_COMPENSATION
	spec.base_mu *= f
	spec.cl_a *= f
	return spec


func driver_skill(code: String, level: int) -> AiSkill:
	var d := driver(code)
	var gap: float = d.get("quali_vs_teammate_pct", 0.0)
	return AiSkill.level(level).for_driver(-gap / 100.0 * DRIVER_WEIGHT)
