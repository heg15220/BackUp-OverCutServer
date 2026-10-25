extends TestCase
## Albert Park in 3D: built from the real data, quickly, and consistent with the physics.

var track := TrackLoader.load_track("res://data/tracks/melbourne_2012.json")


func test_world_builds_with_every_layer_quickly() -> void:
	var t0 := Time.get_ticks_msec()
	var world := TrackWorldBuilder.build(track)
	var ms := Time.get_ticks_msec() - t0
	print("  Albert Park 3D built in %d ms" % ms)
	assert_true(ms < 8000, "%d ms" % ms)
	for layer in ["Terrain", "Asphalt", "Kerbs", "Lines", "Gravel", "Walls", "Lake", "Trees", "Buildings", "Grandstands", "PitBuilding", "StartGantry"]:
		assert_true(world.has_node(layer), "missing " + layer)
	var trees := world.get_node("Trees") as MultiMeshInstance3D
	assert_true(trees.multimesh.instance_count >= 3000, "%d trees" % trees.multimesh.instance_count)
	world.free()


func test_asphalt_follows_the_track_heights() -> void:
	var world := TrackWorldBuilder.build(track)
	var mesh := (world.get_node("Asphalt") as MeshInstance3D).mesh
	var verts: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var geo := TrackGeometry.new(track.data)
	for k in range(0, verts.size(), 997):
		var v := verts[k]
		var p := geo.project(Vector2(v.x, v.z))
		assert_near(v.y, geo.height_at(p), 0.15, "vertex %d" % k)
	world.free()


func test_terrain_never_covers_the_racing_surface() -> void:
	var builder := TrackWorldBuilder.new(track)
	var geo := TrackGeometry.new(track.data)
	for i in range(0, track.data.points.size(), 25):
		var p := track.data.points[i]
		assert_true(builder.terrain_height(p) <= geo.height_at(geo.project(p)) - 0.02, "terrain above asphalt at %d" % i)
