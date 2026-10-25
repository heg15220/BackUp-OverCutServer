extends TestCase
## Convention: Vector2.orthogonal() of the direction of travel is the driver's LEFT
## (Godot's y axis points down), and TrackProjection.lateral is positive to the left.

var data := TestTrackBuilder.build()
var geo := TrackGeometry.new(data)


func _left(i: int) -> Vector2:
	return (data.points[i + 1] - data.points[i]).normalized().orthogonal()


func test_length_about_3_2km() -> void:
	assert_between(data.length(), 3000.0, 3500.0)


func test_projection_on_centerline() -> void:
	var p := geo.project(data.points[100])
	assert_near(p.lateral, 0.0, 0.05)
	assert_eq(p.index, 100)


func test_projection_left_offset_positive() -> void:
	assert_near(geo.project(data.points[100] + _left(100) * 3.0).lateral, 3.0, 0.1)
	assert_near(geo.project(data.points[100] - _left(100) * 3.0).lateral, -3.0, 0.1)


func test_surface_bands() -> void:
	var c := data.points[50]
	var right := -_left(50)
	assert_eq(geo.surface_at(c), Surface.Type.ASPHALT)
	assert_eq(geo.surface_at(c + right * (data.width_right[50] - 0.05)), Surface.Type.WHITE_LINE)
	assert_eq(geo.surface_at(c + right * (data.width_right[50] + 0.7)), Surface.Type.KERB_LOW)
	assert_eq(geo.surface_at(c + right * (data.width_right[50] + 4.0)), data.runoff_right[50])
	assert_eq(geo.surface_at(c + right * (data.wall_right[50] + 1.0)), Surface.Type.WALL)


func test_racing_line_band() -> void:
	assert_eq(geo.surface_at(data.points[50], 0.0), Surface.Type.RACING_LINE)


func test_s_monotonic() -> void:
	assert_true(geo.project(data.points[200]).s > geo.project(data.points[100]).s)


func test_wall_contact_pushes_inside() -> void:
	var c := data.points[50]
	var right := -_left(50)
	var push := geo.wall_contact(c + right * (data.wall_right[50] - 0.5), 1.0)
	assert_true(push.length() > 0.4 and push.dot(-right) > 0.0)
	assert_eq(geo.wall_contact(c, 1.0), Vector2.ZERO)


func test_track_has_gravel_hairpin_and_high_kerb_chicane() -> void:
	assert_true(Array(data.runoff_left).has(Surface.Type.GRAVEL))
	assert_true(Array(data.runoff_left).has(Surface.Type.RUNOFF_ASPHALT))
	assert_true(Array(data.kerb_high_left).has(1))


func test_query_performance() -> void:
	var t0 := Time.get_ticks_msec()
	for i in 10000:
		geo.surface_at(data.points[i % data.points.size()] + Vector2(3, 2))
	var ms := Time.get_ticks_msec() - t0
	print("  surface_at x10k: %d ms" % ms)
	assert_true(ms < 400, "10k consultas < 400 ms (%d ms)" % ms)


func test_hinted_projection_matches_full_search() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for k in 200:
		var i := rng.randi_range(0, data.points.size() - 1)
		var pos := data.points[i] + Vector2(rng.randf_range(-15, 15), rng.randf_range(-15, 15))
		var full := geo.project(pos)
		var hinted := geo.project_hinted(pos, (full.index + rng.randi_range(-3, 3) + data.points.size()) % data.points.size())
		assert_near(hinted.lateral, full.lateral, 1e-3, "point %d" % i)
		assert_near(hinted.s, full.s, 1e-2)


func test_hinted_projection_recovers_from_a_wrong_hint() -> void:
	var pos := data.points[300] + _left(300) * 2.0
	var hinted := geo.project_hinted(pos, 20)
	assert_near(hinted.lateral, 2.0, 0.05)
	assert_eq(hinted.index, 300)


func test_offsets_from_one_projection() -> void:
	var p := geo.project(data.points[60])
	var right := -_left(60)
	assert_near(geo.lateral_at(p, data.points[60] + right * 7.0), -7.0, 0.05)
	assert_eq(geo.surface_for(p, -7.0), Surface.Type.KERB_LOW)
	assert_true(geo.wall_penetration(p, -19.8, 0.55) > 0.3)
	assert_near(geo.wall_penetration(p, 0.0, 0.55), 0.0, 1e-6)
