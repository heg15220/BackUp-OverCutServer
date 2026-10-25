extends Node3D
## Dev scene: the twelve 2012 cars side by side under an overhead camera.
## `-- --capture=<png>` saves a screenshot and quits.

func _ready() -> void:
	var season: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/seasons/2012.json"))
	var helmets := {}
	for d in season["drivers"]:
		if d["starter"] and not helmets.has(d["team"]):
			helmets[d["team"]] = d["helmet"]

	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	add_child(env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -35, 0)
	sun.shadow_enabled = true
	sun.light_energy = 1.2
	add_child(sun)

	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(80, 40)
	ground.mesh = plane
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.22, 0.23, 0.25)
	gm.roughness = 0.95
	ground.material_override = gm
	add_child(ground)

	var i := 0
	for team in season["teams"]:
		var car := CarVisual.new()
		car.setup(team, helmets.get(team["id"], {}))
		car.position = Vector3(-15.0 + (i % 6) * 6.0, 0.0, -4.0 + (i / 6) * 8.0)
		car.rotation.y = PI / 2  # noses pointing up the screen
		add_child(car)
		var tag := Label3D.new()
		tag.text = team["name"]
		tag.font_size = 64
		tag.pixel_size = 0.006
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.position = car.position + Vector3(0, 1.4, 3.2)
		add_child(tag)
		i += 1

	var cam := Camera3D.new()
	cam.fov = 36
	cam.position = Vector3(0, 21, 15)
	add_child(cam)
	cam.look_at(Vector3(0, 0, 0))
	cam.make_current()

	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):
			await get_tree().create_timer(1.0).timeout
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(arg.trim_prefix("--capture="))
			get_tree().quit()
