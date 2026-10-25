extends TestCase
## Terrain height and slope (plan 2, task 2), and loading the real Albert Park.

var spec := CarSpec.baseline_2012()


## Oval whose first straight climbs at `grade` (rise/run); the rest stays flat.
func _ramped_oval(grade: float) -> TrackData:
	var d := TrackFixtures.oval()
	d.heights.resize(d.points.size())
	for i in d.points.size():
		var p := d.points[i]
		d.heights[i] = grade * p.x if p.y == 0.0 else 0.0
	return d


func _speed_after_coasting(track: TrackData) -> float:
	var env := TrackEnvironment.on(track)
	var s := TrackFixtures.car_on_straight(spec, 100.0, 0.0, 30.0)
	SimRunner.run(s, spec, env, 3.0, func(_s, _t): return DriverInput.new())
	return s.speed()


func test_uphill_slows_a_coasting_car() -> void:
	var flat := _speed_after_coasting(TrackFixtures.oval())
	var uphill := _speed_after_coasting(_ramped_oval(0.05))
	# g * 5 % * 3 s ~ 1.47 m/s extra loss
	assert_between(flat - uphill, 1.0, 2.0, "flat %.2f uphill %.2f" % [flat, uphill])


func test_downhill_speeds_it_up() -> void:
	assert_true(_speed_after_coasting(_ramped_oval(-0.05)) > _speed_after_coasting(TrackFixtures.oval()) + 1.0)


func test_height_and_grade_follow_the_track() -> void:
	var geo := TrackGeometry.new(_ramped_oval(0.05))
	var p := geo.project(Vector2(250.0, 1.0))
	assert_near(geo.height_at(p), 12.5, 0.05)
	assert_near(geo.grade_at(p), 0.05, 1e-3)


func test_car_height_follows_the_terrain() -> void:
	var env := TrackEnvironment.on(_ramped_oval(0.05))
	var s := TrackFixtures.car_on_straight(spec, 200.0, 0.0, 20.0)
	VehicleSim.step(s, spec, DriverInput.new(), env, SimClock.TICK)
	assert_near(s.height, 0.05 * s.position.x, 0.05)


func test_flat_track_without_heights_is_level() -> void:
	var geo := TrackGeometry.new(TrackFixtures.oval())
	var p := geo.project(Vector2(250.0, 0.0))
	assert_near(geo.height_at(p), 0.0, 1e-9)
	assert_near(geo.grade_at(p), 0.0, 1e-9)


func test_loader_reads_albert_park() -> void:
	var t := TrackLoader.load_track("res://data/tracks/melbourne_2012.json")
	assert_eq(t.data.points.size(), 1060)
	assert_eq(t.data.heights.size(), 1060)
	assert_between(t.data.length(), 5250.0, 5350.0)
	assert_eq(t.grid.size(), 24)
	assert_eq(t.drs_zones.size(), 1)
	assert_eq(t.laps, 58)
	assert_eq(t.racing_line.size(), 1060)
	assert_true(t.data.runoff_left.has(Surface.Type.GRAVEL))
	assert_true(t.environment.trees.size() > 3000)
	assert_true(t.pit_lane.size() > 10)


func test_albert_park_grid_is_on_the_asphalt() -> void:
	var t := TrackLoader.load_track("res://data/tracks/melbourne_2012.json")
	var geo := TrackGeometry.new(t.data)
	for slot in t.grid:
		var surface := geo.surface_at(slot.position)
		assert_true(surface == Surface.Type.ASPHALT or surface == Surface.Type.WHITE_LINE, "slot on %s" % Surface.Type.keys()[surface])
