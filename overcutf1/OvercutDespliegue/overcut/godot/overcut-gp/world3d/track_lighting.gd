class_name TrackLighting
## Sky, ambient light, fog and the sun for a track scene (Melbourne, March afternoon).


static func add_to(parent: Node3D) -> void:
	var we := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var mat := ProceduralSkyMaterial.new()
	mat.sky_top_color = Color(0.30, 0.52, 0.85)
	mat.sky_horizon_color = Color(0.72, 0.82, 0.92)
	mat.ground_horizon_color = Color(0.72, 0.82, 0.92)
	sky.sky_material = mat
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_energy = 0.35
	e.ambient_light_sky_contribution = 0.6
	e.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED  # no mirror-blue tarmac
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.fog_enabled = true
	e.fog_density = 0.00022
	e.fog_sky_affect = 0.3
	e.fog_light_color = Color(0.75, 0.83, 0.92)
	we.environment = e
	parent.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-52, 140, 0)  # March afternoon in Melbourne: sun to the north-west
	sun.light_energy = 1.05
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 160.0
	parent.add_child(sun)
