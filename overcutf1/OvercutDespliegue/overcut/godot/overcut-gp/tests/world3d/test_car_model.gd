extends TestCase
## 3D car models must respect the 2012 FIA technical regulation envelope.

var season: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/seasons/2012.json"))


func _team(id: String) -> Dictionary:
	for t in season["teams"]:
		if t["id"] == id:
			return t
	return {}


func test_every_team_fits_the_2012_envelope() -> void:
	for team in season["teams"]:
		var aabb := CarModel2012.build_body(team).get_aabb()
		assert_true(aabb.size.x <= 5.25, "%s length %.2f" % [team["id"], aabb.size.x])
		assert_true(aabb.size.z <= 1.801, "%s width %.3f" % [team["id"], aabb.size.z])
		assert_true(aabb.position.y + aabb.size.y <= 0.951, "%s height %.3f" % [team["id"], aabb.position.y + aabb.size.y])
		assert_true(aabb.position.y >= -0.001, "%s below the ground" % team["id"])


func test_wheels_sit_on_the_wheelbase_and_tracks() -> void:
	var team := _team("mercedes")
	var w := CarModel2012.wheel_layout(team)
	assert_near(w[0].position.x - w[2].position.x, float(team["car"]["wheelbase"]), 1e-4)
	assert_near(w[0].position.y, CarModel2012.TYRE_RADIUS, 1e-6)
	assert_near(w[0].width, 0.245, 1e-6)
	assert_near(w[2].width, 0.325, 1e-6)
	assert_true(absf(w[0].position.z) + w[0].width * 0.5 <= 0.9 + 1e-4, "front tyre inside 1.8 m")
	assert_true(absf(w[2].position.z) + w[2].width * 0.5 <= 0.9 + 1e-4, "rear tyre inside 1.8 m")


func test_livery_colours_are_painted() -> void:
	var team := _team("caterham")
	var colors := CarModel2012.build_body(team).surface_get_arrays(0)[Mesh.ARRAY_COLOR] as PackedColorArray
	assert_true(colors.has(Color(team["colors"]["primary"])), "primary green")
	assert_true(colors.has(Color(team["colors"]["accent"])) or colors.has(Color(team["colors"]["secondary"])), "yellow")


func test_stepped_nose_except_mclaren() -> void:
	# The 2012 nose rule: chassis up to 625 mm, nose no higher than 550 mm ahead of it.
	assert_true(CarModel2012.nose_step_height(_team("ferrari")) > 0.05)
	assert_near(CarModel2012.nose_step_height(_team("mclaren")), 0.0, 1e-6)
