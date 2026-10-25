extends TestCase
## Championship state: points, standings and saving.

var model := SeasonModel.load_2012()


func _new() -> Championship:
	return Championship.create(model, "mclaren", "HAM", AiSkill.PROFESSIONAL, RaceRules.Length.LAPS_5)


func test_new_championship_starts_at_round_one() -> void:
	var c := _new()
	assert_eq(c.round, 1)
	assert_eq(c.next_gp()["id"], "australia")
	assert_eq(c.driver_points.size(), 0)


func test_race_result_awards_2012_points() -> void:
	var c := _new()
	c.record_race("australia", ["BUT", "VET", "HAM", "WEB", "ALO", "KOB", "RAI", "PER", "RIC", "DIR", "VER"], "BUT")
	assert_eq(c.driver_points["BUT"], 25)
	assert_eq(c.driver_points["HAM"], 15)
	assert_eq(c.driver_points.get("VER", 0), 0)
	assert_eq(c.team_points["mclaren"], 40)
	assert_eq(c.team_points["red-bull"], 30)
	assert_eq(c.round, 2)
	assert_eq(c.driver_standings()[0][0], "BUT")


func test_save_and_load_roundtrip() -> void:
	var c := _new()
	c.record_race("australia", ["HAM", "BUT"], "HAM")
	var path := "user://test_championship.json"
	c.save(path)
	var d := Championship.load_from(path, model)
	assert_eq(d.player_code, "HAM")
	assert_eq(d.round, 2)
	assert_eq(d.driver_points["HAM"], 25)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
