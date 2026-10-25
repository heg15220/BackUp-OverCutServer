class_name TrackMeshBuilder
## Builds the visual track from TrackData: one mesh per band (ground, run-off per
## surface type, asphalt, white lines, kerbs) plus wall lines. 1 world unit = 1 m.
## Mesh UVs carry (distance along track, lateral offset) for the shaders.

const GROUND_MARGIN := 300.0
const WALL_WIDTH := 0.6

const ASPHALT := preload("res://render/shaders/asphalt.gdshader")
const KERB := preload("res://render/shaders/kerb.gdshader")
const GRAVEL := preload("res://render/shaders/gravel.gdshader")
const GRASS := preload("res://render/shaders/grass.gdshader")


static func build(data: TrackData) -> Node2D:
	var root := Node2D.new()
	root.name = "Track"
	var n := data.points.size()
	var normals := _left_normals(data.points)
	var s := PackedFloat32Array()
	s.resize(n + 1)
	for i in n:
		s[i + 1] = s[i] + data.points[i].distance_to(data.points[(i + 1) % n])

	_add(root, "Ground", _ground_mesh(data.points), _material(GRASS))

	var runoff := {}  # Surface.Type -> [verts, uvs]
	var asphalt := [PackedVector2Array(), PackedVector2Array()]
	var lines := [PackedVector2Array(), PackedVector2Array()]
	var kerbs := [PackedVector2Array(), PackedVector2Array()]
	var high_kerbs := [PackedVector2Array(), PackedVector2Array()]
	for i in n:
		var j := (i + 1) % n
		var sj := s[i + 1]
		_quad(asphalt, data, normals, s, i, j, sj, -data.width_right[i], -data.width_right[j], data.width_left[i], data.width_left[j])
		for side in [1.0, -1.0]:
			var w_i: float = data.width_left[i] if side > 0 else data.width_right[i]
			var w_j: float = data.width_left[j] if side > 0 else data.width_right[j]
			var k_i: float = data.kerb_left[i] if side > 0 else data.kerb_right[i]
			var k_j: float = data.kerb_left[j] if side > 0 else data.kerb_right[j]
			var wall_i: float = data.wall_left[i] if side > 0 else data.wall_right[i]
			var wall_j: float = data.wall_left[j] if side > 0 else data.wall_right[j]
			var lw := TrackGeometry.WHITE_LINE_WIDTH
			_quad(lines, data, normals, s, i, j, sj, side * (w_i - lw), side * (w_j - lw), side * w_i, side * w_j)
			if k_i > 0.0 or k_j > 0.0:
				var high: int = (data.kerb_high_left if side > 0 else data.kerb_high_right)[i]
				_quad(high_kerbs if high == 1 else kerbs, data, normals, s, i, j, sj, side * w_i, side * w_j, side * (w_i + k_i), side * (w_j + k_j))
			var type: int = (data.runoff_left if side > 0 else data.runoff_right)[i]
			if not runoff.has(type):
				runoff[type] = [PackedVector2Array(), PackedVector2Array()]
			_quad(runoff[type], data, normals, s, i, j, sj, side * (w_i + k_i), side * (w_j + k_j), side * wall_i, side * wall_j)

	for type in runoff:
		var mat: ShaderMaterial
		match type:
			Surface.Type.GRAVEL:
				mat = _material(GRAVEL)
			Surface.Type.GRASS:
				mat = _material(GRASS)
			_:
				mat = _material(ASPHALT, {"base_color": Color(0.36, 0.37, 0.38), "rubber_strength": 0.0})
		_add(root, "Runoff_%s" % Surface.Type.keys()[type], _mesh(runoff[type]), mat)
	_add(root, "Asphalt", _mesh(asphalt), _material(ASPHALT))
	_add(root, "WhiteLines", _mesh(lines), null, Color(0.93, 0.93, 0.93))
	_add(root, "Kerbs", _mesh(kerbs), _material(KERB))
	_add(root, "HighKerbs", _mesh(high_kerbs), _material(KERB, {"color_a": Color(0.95, 0.80, 0.10), "color_b": Color(0.12, 0.12, 0.12), "stripe_length": 0.8}))

	var walls := Node2D.new()
	walls.name = "Walls"
	root.add_child(walls)
	for side in [1.0, -1.0]:
		var line := Line2D.new()
		line.width = WALL_WIDTH
		line.default_color = Color(0.62, 0.63, 0.66)
		line.closed = true
		var shadow := Line2D.new()
		shadow.width = WALL_WIDTH * 1.6
		shadow.default_color = Color(0, 0, 0, 0.3)
		shadow.closed = true
		for i in n:
			var off: float = data.wall_left[i] if side > 0 else data.wall_right[i]
			var p: Vector2 = data.points[i] + normals[i] * side * off
			line.add_point(p)
			shadow.add_point(p + Vector2(0.25, 0.35))
		walls.add_child(shadow)
		walls.add_child(line)
	return root


static func _left_normals(points: PackedVector2Array) -> PackedVector2Array:
	var n := points.size()
	var out := PackedVector2Array()
	out.resize(n)
	for i in n:
		var t := (points[(i + 1) % n] - points[(i - 1 + n) % n]).normalized()
		out[i] = t.orthogonal()  # driver's left in Godot's y-down space
	return out


## Appends the quad between lateral offsets (a -> b) on segment i -> j to strip [verts, uvs].
static func _quad(strip: Array, data: TrackData, normals: PackedVector2Array, s: PackedFloat32Array, i: int, j: int, sj: float, a_i: float, a_j: float, b_i: float, b_j: float) -> void:
	var p_i := data.points[i]
	var p_j := data.points[j]
	var v0 := p_i + normals[i] * a_i
	var v1 := p_j + normals[j] * a_j
	var v2 := p_j + normals[j] * b_j
	var v3 := p_i + normals[i] * b_i
	strip[0].append_array([v0, v1, v2, v0, v2, v3])
	strip[1].append_array([Vector2(s[i], a_i), Vector2(sj, a_j), Vector2(sj, b_j), Vector2(s[i], a_i), Vector2(sj, b_j), Vector2(s[i], b_i)])


static func _ground_mesh(points: PackedVector2Array) -> ArrayMesh:
	var r := Rect2(points[0], Vector2.ZERO)
	for p in points:
		r = r.expand(p)
	r = r.grow(GROUND_MARGIN)
	var verts := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, r.position, r.end, Vector2(r.position.x, r.end.y)])
	return _mesh([verts, verts.duplicate()])


static func _mesh(strip: Array) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	if strip[0].is_empty():
		return mesh
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = strip[0]
	arrays[Mesh.ARRAY_TEX_UV] = strip[1]
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func _material(shader: Shader, params := {}) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader
	for k in params:
		m.set_shader_parameter(k, params[k])
	return m


static func _add(root: Node2D, node_name: String, mesh: ArrayMesh, material: Material, modulate := Color.WHITE) -> void:
	var mi := MeshInstance2D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.material = material
	mi.modulate = modulate
	root.add_child(mi)
