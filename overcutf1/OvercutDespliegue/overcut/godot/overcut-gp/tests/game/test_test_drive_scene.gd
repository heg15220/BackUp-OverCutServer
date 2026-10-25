extends TestCase


func test_test_drive_scene_runs() -> void:
	var scene: Node = load("res://scenes/dev/test_drive.tscn").instantiate()
	tree.root.add_child(scene)
	await tree.process_frame
	var controller: CarController = scene.controller
	controller.input_source = SimRunner.full_throttle
	for i in 600:
		await tree.physics_frame
	assert_true(controller.state.distance_m > 100.0, "travelled %.1f m" % controller.state.distance_m)
	assert_true(controller.state.position.is_finite())
	scene.queue_free()
	await tree.process_frame


func test_track_mesh_has_every_band() -> void:
	var node := TrackMeshBuilder.build(TestTrackBuilder.build())
	var names := node.get_children().map(func(c): return String(c.name))
	for band in ["Ground", "Asphalt", "WhiteLines", "Kerbs", "HighKerbs", "Runoff_GRAVEL", "Runoff_GRASS", "Runoff_RUNOFF_ASPHALT", "Walls"]:
		assert_true(band in names, "missing %s in %s" % [band, str(names)])
	node.free()
