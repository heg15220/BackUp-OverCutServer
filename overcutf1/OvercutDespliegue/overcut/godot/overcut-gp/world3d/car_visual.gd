class_name CarVisual
extends Node3D
## A 2012 car in the 3D world: the procedural body plus four wheels that steer and roll.
## The physics runs in 2D (x east, y south); the world maps it to 3D as (x, height, y).

const TYRE_COLOR := Color(0.06, 0.06, 0.065)
const RIM_COLOR := Color(0.55, 0.56, 0.58)
## Pirelli 2012 sidewall colours.
const COMPOUND_COLORS := {
	&"supersoft": Color(0.86, 0.08, 0.10), &"soft": Color(0.98, 0.82, 0.10),
	&"medium": Color(0.95, 0.95, 0.95), &"hard": Color(0.70, 0.72, 0.75),
	&"intermediate": Color(0.20, 0.70, 0.30), &"wet": Color(0.15, 0.45, 0.90),
}
const CHROME_TEAMS := ["mclaren", "mercedes"]

var team: Dictionary
var _wheels: Array[Node3D] = []
var _wheel_specs: Array[CarModel2012.WheelSpec] = []
var _bands: Array[MeshInstance3D] = []
var _roll := 0.0
var _compound := &""


func setup(team_data: Dictionary, helmet: Dictionary = {}) -> void:
	team = team_data.duplicate(true)
	if not helmet.is_empty():
		team["helmet"] = helmet
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = CarModel2012.build_body(team)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 0.32
	mat.metallic = 0.75 if team["id"] in CHROME_TEAMS else 0.25
	mat.metallic_specular = 0.6
	body.material_override = mat
	add_child(body)
	_wheel_specs = CarModel2012.wheel_layout(team)
	for spec in _wheel_specs:
		var pivot := Node3D.new()  # steers around Y
		pivot.position = spec.position
		add_child(pivot)
		var spin := Node3D.new()  # rolls around Z
		pivot.add_child(spin)
		spin.add_child(_cylinder(CarModel2012.TYRE_RADIUS, spec.width, TYRE_COLOR, 0.9))
		spin.add_child(_cylinder(0.2, spec.width + 0.01, RIM_COLOR, 0.35, 0.6))
		var band := _cylinder(CarModel2012.TYRE_RADIUS * 0.82, spec.width + 0.006, COMPOUND_COLORS[&"medium"], 0.5)
		spin.add_child(band)
		_bands.append(band)
		_wheels.append(pivot)


## Places the car from the physics state (2D) on the 3D world.
func sync(state: CarState, pos2d: Vector2, heading: float) -> void:
	position = Vector3(pos2d.x, state.height, pos2d.y)
	rotation = Vector3(0.0, -heading, 0.0)
	_roll -= state.local_velocity().x * get_process_delta_time() / CarModel2012.TYRE_RADIUS
	for i in _wheels.size():
		var pivot := _wheels[i]
		pivot.rotation.y = -state.steer_angle if _wheel_specs[i].front else 0.0
		(pivot.get_child(0) as Node3D).rotation.z = _roll
	var compound := state.wheels[0].tyre.compound.id
	if compound != _compound:
		_compound = compound
		for band in _bands:
			(band.material_override as StandardMaterial3D).albedo_color = COMPOUND_COLORS.get(compound, Color.WHITE)


func _cylinder(radius: float, width: float, color: Color, roughness: float, metallic := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = width
	mesh.radial_segments = 18
	mesh.rings = 1
	mi.mesh = mesh
	mi.rotation.x = PI / 2  # cylinder axis along Z (the axle)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic = metallic
	mi.material_override = mat
	return mi
