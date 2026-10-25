class_name TrackWorldBuilder
extends RefCounted
## Builds a circuit's static 3D world from a LoadedTrack: terrain from the DEM (flattened
## under the racing surface), the asphalt ribbon with its real heights, kerbs, white lines,
## gravel traps, walls and tyre barriers, the lake, OSM trees and buildings, grandstands,
## the pit building and the start gantry. 2D (x, y) maps to 3D (x, height, y).

const TERRAIN_MARGIN := 260.0
const TERRAIN_CELL := 12.0
const BLEND := 40.0
const WALL_HEIGHT := 0.95
const WALL_THICKNESS := 0.4

const ASPHALT := preload("res://world3d/shaders/asphalt3d.gdshader")
const KERB := preload("res://world3d/shaders/kerb3d.gdshader")
const GRAVEL := preload("res://world3d/shaders/gravel3d.gdshader")
const TERRAIN := preload("res://world3d/shaders/terrain3d.gdshader")
const WATER := preload("res://world3d/shaders/water3d.gdshader")
const CROWD := preload("res://world3d/shaders/crowd3d.gdshader")

var track: LoadedTrack
var geo: TrackGeometry
var water_level := 0.0
var _normals := PackedVector2Array()
var _s := PackedFloat32Array()
var _grid_origin := Vector2.ZERO
var _grid_nx := 0
var _grid_ny := 0
var _grid_h := PackedFloat32Array()
## Nearest centreline index per terrain vertex within NEAR_RADIUS, -1 beyond (no projection needed).
var _grid_near := PackedInt32Array()
const NEAR_RADIUS := 150.0


static func build(loaded: LoadedTrack) -> Node3D:
	var b := TrackWorldBuilder.new(loaded)
	return b.build_world()


func _init(loaded: LoadedTrack) -> void:
	track = loaded
	geo = TrackGeometry.new(loaded.data)
	var pts := loaded.data.points
	var n := pts.size()
	_normals.resize(n)
	_s.resize(n + 1)
	for i in n:
		_normals[i] = (pts[(i + 1) % n] - pts[(i - 1 + n) % n]).normalized().orthogonal()
		_s[i + 1] = _s[i] + pts[i].distance_to(pts[(i + 1) % n])
	water_level = _lake_level()
	_build_height_grid()


func build_world() -> Node3D:
	var root := Node3D.new()
	root.name = "World"
	_add(root, "Terrain", _terrain_mesh(), _shader(TERRAIN))
	_add(root, "Asphalt", _ribbon(func(i, side): return [-track.data.width_right[i], track.data.width_left[i]], 0.0, true), _shader(ASPHALT))
	_add(root, "Lines", _side_ribbons(func(w, k, wall): return [w - TrackGeometry.WHITE_LINE_WIDTH, w], 0.004, func(i, side): return true), _plain(Color(0.94, 0.94, 0.94), 0.6))
	_add(root, "Kerbs", _side_ribbons(func(w, k, wall): return [w, w + k], 0.03, func(i, side): return (track.data.kerb_left if side > 0 else track.data.kerb_right)[i] > 0.0), _shader(KERB))
	_add(root, "Gravel", _side_ribbons(func(w, k, wall): return [w + k, wall - 0.3], -0.01, func(i, side): return (track.data.runoff_left if side > 0 else track.data.runoff_right)[i] == Surface.Type.GRAVEL), _shader(GRAVEL))
	root.add_child(_walls())
	_add(root, "Lake", _lake_mesh(), _shader(WATER))
	root.add_child(_trees())
	_add(root, "Buildings", _buildings_mesh(), _vertex_color_material(0.85))
	_add(root, "Grandstands", _grandstands_mesh(), _shader(CROWD))
	root.add_child(_pit_building())
	root.add_child(_start_gantry())
	return root


## Ground height at a 2D point (bilinear on the flattened terrain grid).
func terrain_height(p: Vector2) -> float:
	var gx := (p.x - _grid_origin.x) / TERRAIN_CELL
	var gy := (p.y - _grid_origin.y) / TERRAIN_CELL
	var i0 := clampi(floori(gx), 0, _grid_nx - 2)
	var j0 := clampi(floori(gy), 0, _grid_ny - 2)
	var fx := clampf(gx - i0, 0.0, 1.0)
	var fy := clampf(gy - j0, 0.0, 1.0)
	var h00 := _grid_h[j0 * _grid_nx + i0]
	var h10 := _grid_h[j0 * _grid_nx + i0 + 1]
	var h01 := _grid_h[(j0 + 1) * _grid_nx + i0]
	var h11 := _grid_h[(j0 + 1) * _grid_nx + i0 + 1]
	return lerpf(lerpf(h00, h10, fx), lerpf(h01, h11, fx), fy)


# --- Terrain ---------------------------------------------------------------------------------

func _dem(p: Vector2) -> float:
	var t := track.terrain
	if t.is_empty():
		return 0.0
	var gx := (p.x - float(t["x0"])) / float(t["step"])
	var gy := (p.y - float(t["y0"])) / float(t["step"])
	var nx := int(t["nx"])
	var ny := int(t["ny"])
	var i0 := clampi(floori(gx), 0, nx - 2)
	var j0 := clampi(floori(gy), 0, ny - 2)
	var fx := clampf(gx - i0, 0.0, 1.0)
	var fy := clampf(gy - j0, 0.0, 1.0)
	var h: Array = t["heights"]
	return lerpf(lerpf(h[j0 * nx + i0], h[j0 * nx + i0 + 1], fx), lerpf(h[(j0 + 1) * nx + i0], h[(j0 + 1) * nx + i0 + 1], fx), fy)


func _lake_level() -> float:
	var lake := track.environment.lake
	if lake.is_empty():
		return -100.0
	var hs: Array[float] = []
	for p in lake:
		hs.append(_dem(p))
	hs.sort()
	var min_track := INF
	for h in track.data.heights:
		min_track = minf(min_track, h)
	return minf(hs[hs.size() / 5], min_track - 0.6)


func _build_height_grid() -> void:
	var lo := track.data.points[0]
	var hi := lo
	for p in track.data.points:
		lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
		hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
	_grid_origin = lo - Vector2.ONE * TERRAIN_MARGIN
	_grid_nx = int((hi.x - lo.x + 2.0 * TERRAIN_MARGIN) / TERRAIN_CELL) + 2
	_grid_ny = int((hi.y - lo.y + 2.0 * TERRAIN_MARGIN) / TERRAIN_CELL) + 2
	_grid_h.resize(_grid_nx * _grid_ny)
	_rasterise_nearest()
	var lake := track.environment.lake
	var lake_box := Rect2()
	if not lake.is_empty():
		lake_box = Rect2(lake[0], Vector2.ZERO)
		for p in lake:
			lake_box = lake_box.expand(p)
	for j in _grid_ny:
		for i in _grid_nx:
			var p := _grid_origin + Vector2(i, j) * TERRAIN_CELL
			var h := _dem(p)
			var near := _grid_near[j * _grid_nx + i]
			if near < 0:
				if lake_box.has_point(p) and Geometry2D.is_point_in_polygon(p, lake):
					h = minf(h, water_level - 1.2)
				_grid_h[j * _grid_nx + i] = h
				continue
			var proj := geo.project_local(p, near)
			var left := proj.lateral >= 0.0
			var wall := (track.data.wall_left if left else track.data.wall_right)[proj.index]
			var d := absf(proj.lateral)
			var flat := geo.height_at(proj) - 0.05
			if d <= wall + 2.0:
				h = flat
			elif d < wall + 2.0 + BLEND:
				h = lerpf(flat, h, smoothstep(0.0, 1.0, (d - wall - 2.0) / BLEND))
			if lake_box.has_point(p) and Geometry2D.is_point_in_polygon(p, lake):
				h = minf(h, water_level - 1.2)
			_grid_h[j * _grid_nx + i] = h


## For every terrain vertex, the closest centreline point within NEAR_RADIUS (splatting each
## centreline point over the cells around it is far cheaper than projecting every vertex).
func _rasterise_nearest() -> void:
	_grid_near.resize(_grid_nx * _grid_ny)
	_grid_near.fill(-1)
	var best := PackedFloat32Array()
	best.resize(_grid_nx * _grid_ny)
	best.fill(NEAR_RADIUS * NEAR_RADIUS)
	var r := ceili(NEAR_RADIUS / TERRAIN_CELL)
	var pts := track.data.points
	for k in pts.size():
		var c := (pts[k] - _grid_origin) / TERRAIN_CELL
		var ci := roundi(c.x)
		var cj := roundi(c.y)
		for j in range(maxi(0, cj - r), mini(_grid_ny, cj + r + 1)):
			for i in range(maxi(0, ci - r), mini(_grid_nx, ci + r + 1)):
				var d2 := (_grid_origin + Vector2(i, j) * TERRAIN_CELL).distance_squared_to(pts[k])
				var idx := j * _grid_nx + i
				if d2 < best[idx]:
					best[idx] = d2
					_grid_near[idx] = k


## Nearest centreline index for any 2D point (via the closest terrain vertex), -1 if far away.
func _near_index(p: Vector2) -> int:
	var i := clampi(roundi((p.x - _grid_origin.x) / TERRAIN_CELL), 0, _grid_nx - 1)
	var j := clampi(roundi((p.y - _grid_origin.y) / TERRAIN_CELL), 0, _grid_ny - 1)
	return _grid_near[j * _grid_nx + i]


func _terrain_mesh() -> ArrayMesh:
	var park := _park_mask()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in _grid_ny:
		for i in _grid_nx:
			var p := _grid_origin + Vector2(i, j) * TERRAIN_CELL
			st.set_color(Color(park[j * _grid_nx + i], 0, 0))
			st.set_uv(p)
			st.add_vertex(Vector3(p.x, _grid_h[j * _grid_nx + i], p.y))
	for j in _grid_ny - 1:
		for i in _grid_nx - 1:
			var a := j * _grid_nx + i
			var b := a + 1
			var c := a + _grid_nx
			var d := c + 1
			for idx in [a, b, d, a, d, c]:  # clockwise seen from above
				st.add_index(idx)
	st.generate_normals()
	return st.commit()


## 1 inside parks and near the circuit, 0 in the streets around it.
func _park_mask() -> PackedFloat32Array:
	var mask := PackedFloat32Array()
	mask.resize(_grid_nx * _grid_ny)
	for park in track.environment.parks:
		var poly: PackedVector2Array = park["polygon"]
		if poly.size() < 3:
			continue
		var box := Rect2(poly[0], Vector2.ZERO)
		for q in poly:
			box = box.expand(q)
		var i0 := maxi(0, floori((box.position.x - _grid_origin.x) / TERRAIN_CELL))
		var i1 := mini(_grid_nx - 1, ceili((box.end.x - _grid_origin.x) / TERRAIN_CELL))
		var j0 := maxi(0, floori((box.position.y - _grid_origin.y) / TERRAIN_CELL))
		var j1 := mini(_grid_ny - 1, ceili((box.end.y - _grid_origin.y) / TERRAIN_CELL))
		for j in range(j0, j1 + 1):
			for i in range(i0, i1 + 1):
				if Geometry2D.is_point_in_polygon(_grid_origin + Vector2(i, j) * TERRAIN_CELL, poly):
					mask[j * _grid_nx + i] = 1.0
	for j in _grid_ny:
		for i in _grid_nx:
			var idx := j * _grid_nx + i
			var near := _grid_near[idx]
			if near < 0:
				continue
			var p := _grid_origin + Vector2(i, j) * TERRAIN_CELL
			var proj := geo.project_local(p, near)
			mask[idx] = maxf(mask[idx], 1.0 - smoothstep(60.0, 140.0, absf(proj.lateral)))
	return mask


# --- Track surfaces --------------------------------------------------------------------------

## The racing surface between two lateral offsets returned by `span(i, side)`.
func _ribbon(span: Callable, lift: float, racing_line_uv2: bool) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := track.data.points.size()
	for i in n:
		var j := (i + 1) % n
		var a: Array = span.call(i, 0)
		var b: Array = span.call(j, 0)
		_strip_quad(st, i, j, a[0], a[1], b[0], b[1], lift, racing_line_uv2)
	st.generate_normals()
	return st.commit()


## Ribbons on both sides; `band(width, kerb, wall)` gives [inner, outer] offsets from the centre.
func _side_ribbons(band: Callable, lift: float, include: Callable) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var d := track.data
	var n := d.points.size()
	var any := false
	for i in n:
		var j := (i + 1) % n
		for side in [1.0, -1.0]:
			if not include.call(i, side):
				continue
			var bi: Array = band.call(d.width_left[i] if side > 0 else d.width_right[i], d.kerb_left[i] if side > 0 else d.kerb_right[i], d.wall_left[i] if side > 0 else d.wall_right[i])
			var bj: Array = band.call(d.width_left[j] if side > 0 else d.width_right[j], d.kerb_left[j] if side > 0 else d.kerb_right[j], d.wall_left[j] if side > 0 else d.wall_right[j])
			if side > 0:
				_strip_quad(st, i, j, bi[0], bi[1], bj[0], bj[1], lift, false)
			else:
				_strip_quad(st, i, j, -bi[1], -bi[0], -bj[1], -bj[0], lift, false)
			any = true
	if not any:
		return ArrayMesh.new()
	st.generate_normals()
	return st.commit()


## Quad on segment i -> j between lateral offsets (right edge a0/b0, left edge a1/b1).
func _strip_quad(st: SurfaceTool, i: int, j: int, a0: float, a1: float, b0: float, b1: float, lift: float, rl: bool) -> void:
	var d := track.data
	var hi := d.heights[i] + lift
	var hj := d.heights[j] + lift
	var pi := d.points[i]
	var pj := d.points[j]
	var sj := _s[i + 1]
	var v := [Vector3((pi + _normals[i] * a0).x, hi, (pi + _normals[i] * a0).y), Vector3((pi + _normals[i] * a1).x, hi, (pi + _normals[i] * a1).y),
		Vector3((pj + _normals[j] * b1).x, hj, (pj + _normals[j] * b1).y), Vector3((pj + _normals[j] * b0).x, hj, (pj + _normals[j] * b0).y)]
	var uv := [Vector2(_s[i], a0), Vector2(_s[i], a1), Vector2(sj, b1), Vector2(sj, b0)]
	var rli := track.racing_line[i] if rl and not track.racing_line.is_empty() else 0.0
	var rlj := track.racing_line[j] if rl and not track.racing_line.is_empty() else 0.0
	var uv2 := [Vector2(rli, 0), Vector2(rli, 0), Vector2(rlj, 0), Vector2(rlj, 0)]
	# v0/v3 are the right edge, v1/v2 the left edge: seen from above (+Y), 0-1-2 is clockwise.
	for k in [0, 1, 2, 0, 2, 3]:
		st.set_uv(uv[k])
		st.set_uv2(uv2[k])
		st.add_vertex(v[k])


# --- Walls -----------------------------------------------------------------------------------

func _walls() -> Node3D:
	var node := Node3D.new()
	node.name = "Walls"
	var concrete := SurfaceTool.new()
	concrete.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tyres := SurfaceTool.new()
	tyres.begin(Mesh.PRIMITIVE_TRIANGLES)
	var d := track.data
	var n := d.points.size()
	for side in [1.0, -1.0]:
		for i in n:
			var j := (i + 1) % n
			var wi: float = d.wall_left[i] if side > 0 else d.wall_right[i]
			var wj: float = d.wall_left[j] if side > 0 else d.wall_right[j]
			var gravel: bool = (d.runoff_left if side > 0 else d.runoff_right)[i] == Surface.Type.GRAVEL
			var a: Vector2 = d.points[i] + _normals[i] * side * wi
			var b: Vector2 = d.points[j] + _normals[j] * side * wj
			var out_a: Vector2 = _normals[i] * side * WALL_THICKNESS
			var out_b: Vector2 = _normals[j] * side * WALL_THICKNESS
			var ha := terrain_height(a) - 0.2
			var hb := terrain_height(b) - 0.2
			var top := WALL_HEIGHT + 0.2
			var st := tyres if gravel else concrete
			_box_between(st, a, b, out_a, out_b, ha, hb, top)
	_add(node, "Concrete", concrete.commit(), _plain(Color(0.72, 0.72, 0.70), 0.9))
	_add(node, "TyreBarriers", tyres.commit(), _plain(Color(0.10, 0.10, 0.12), 0.95))
	return node


## A wall segment from a to b (inner face) extruded outwards by out_* and up by top.
func _box_between(st: SurfaceTool, a: Vector2, b: Vector2, out_a: Vector2, out_b: Vector2, ha: float, hb: float, top: float) -> void:
	var a2 := a + out_a
	var b2 := b + out_b
	var faces := [
		[Vector3(a.x, ha, a.y), Vector3(b.x, hb, b.y), Vector3(b.x, hb + top, b.y), Vector3(a.x, ha + top, a.y)],
		[Vector3(a.x, ha + top, a.y), Vector3(b.x, hb + top, b.y), Vector3(b2.x, hb + top, b2.y), Vector3(a2.x, ha + top, a2.y)],
		[Vector3(a2.x, ha, a2.y), Vector3(a2.x, ha + top, a2.y), Vector3(b2.x, hb + top, b2.y), Vector3(b2.x, hb, b2.y)],
	]
	var inside := Vector3((a.x + b.x + a2.x + b2.x) * 0.25, (ha + hb) * 0.5 + top * 0.5, (a.y + b.y + a2.y + b2.y) * 0.25)
	for f in faces:
		_outward_quad(st, f[0], f[1], f[2], f[3], inside)


## Quad with its normal pointing away from `inside`, wound clockwise as seen from outside.
func _outward_quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, inside: Vector3) -> void:
	var n := (b - a).cross(c - a).normalized()
	if n.dot((a + b + c + d) * 0.25 - inside) < 0.0:
		n = -n
	for tri in [[a, b, c], [a, c, d]]:
		var v0: Vector3 = tri[0]
		var v1: Vector3 = tri[1]
		var v2: Vector3 = tri[2]
		if (v1 - v0).cross(v2 - v0).dot(n) > 0.0:
			var t := v1
			v1 = v2
			v2 = t
		for v in [v0, v1, v2]:
			st.set_normal(n)
			st.add_vertex(v)


# --- Lake, trees, buildings, grandstands ---------------------------------------------------

func _lake_mesh() -> ArrayMesh:
	var lake := track.environment.lake
	if lake.size() < 3:
		return ArrayMesh.new()
	var idx := Geometry2D.triangulate_polygon(lake)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	for k in range(0, idx.size(), 3):
		var tri := [lake[idx[k]], lake[idx[k + 1]], lake[idx[k + 2]]]
		var cross: float = (tri[1] - tri[0]).cross(tri[2] - tri[0])
		var order := [0, 1, 2] if cross > 0.0 else [0, 2, 1]
		for o in order:
			st.add_vertex(Vector3(tri[o].x, water_level, tri[o].y))
	return st.commit()


func _trees() -> MultiMeshInstance3D:
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Trees"
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _tree_mesh()
	var keep := PackedVector2Array()
	for t in track.environment.trees:
		var near := _near_index(t)
		if near < 0:
			keep.append(t)
			continue
		var p := geo.project_local(t, near)
		var wall := (track.data.wall_left if p.lateral >= 0.0 else track.data.wall_right)[p.index]
		if absf(p.lateral) > wall + 2.5:
			keep.append(t)
	mm.instance_count = keep.size()
	for k in keep.size():
		var t := keep[k]
		var h := fposmod(sin(t.x * 12.9898 + t.y * 78.233) * 43758.5453, 1.0)
		var s := 0.75 + 0.7 * h
		var basis := Basis(Vector3.UP, h * TAU).scaled(Vector3(s, s * (0.85 + 0.3 * h), s))
		mm.set_instance_transform(k, Transform3D(basis, Vector3(t.x, terrain_height(t), t.y)))
		mm.set_instance_color(k, Color(0.75 + 0.25 * h, 0.85 + 0.15 * (1.0 - h), 0.7 + 0.2 * h))
	mmi.multimesh = mm
	var mat := _vertex_color_material(0.9)
	mmi.material_override = mat
	return mmi


func _tree_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var trunk := Color(0.33, 0.24, 0.16)
	var leaves := Color(0.20, 0.38, 0.16)
	# trunk: 6-sided prism
	for k in 6:
		var a0 := TAU * k / 6.0
		var a1 := TAU * (k + 1) / 6.0
		var p0 := Vector3(cos(a0), 0, sin(a0)) * 0.3
		var p1 := Vector3(cos(a1), 0, sin(a1)) * 0.3
		_tri(st, p0, p1 + Vector3(0, 3.0, 0), p1, trunk)
		_tri(st, p0, p0 + Vector3(0, 3.0, 0), p1 + Vector3(0, 3.0, 0), trunk)
	# crown: two stacked octahedra-ish blobs
	for crown in [[Vector3(0, 5.0, 0), 3.2, 2.6], [Vector3(0.6, 6.6, 0.3), 2.2, 1.8]]:
		var c: Vector3 = crown[0]
		var r: float = crown[1]
		var hh: float = crown[2]
		for k in 8:
			var a0 := TAU * k / 8.0
			var a1 := TAU * (k + 1) / 8.0
			var e0 := c + Vector3(cos(a0) * r, 0, sin(a0) * r)
			var e1 := c + Vector3(cos(a1) * r, 0, sin(a1) * r)
			_tri(st, e0, c + Vector3(0, hh, 0), e1, leaves)
			_tri(st, e0, e1, c - Vector3(0, hh * 0.8, 0), leaves.darkened(0.15))
	st.generate_normals()
	return st.commit()


func _buildings_mesh() -> ArrayMesh:
	var palette := [Color(0.86, 0.82, 0.74), Color(0.72, 0.42, 0.32), Color(0.93, 0.93, 0.92), Color(0.62, 0.62, 0.64), Color(0.80, 0.70, 0.55)]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for b in track.environment.buildings:
		var poly: PackedVector2Array = b["footprint"]
		if poly.size() < 3:
			continue
		var c := Vector2.ZERO
		for q in poly:
			c += q
		c /= poly.size()
		var base := terrain_height(c) - 0.5
		var top := base + 0.5 + float(b["height"])
		var color: Color = palette[int(absf(c.x * 7.0 + c.y * 13.0)) % palette.size()]
		var ccw := _signed_area(poly) < 0.0  # y-down: negative area = counter-clockwise on screen
		for k in poly.size():
			var p0 := poly[k]
			var p1 := poly[(k + 1) % poly.size()]
			var q0 := Vector3(p0.x, base, p0.y)
			var q1 := Vector3(p1.x, base, p1.y)
			if ccw:
				_tri(st, q0, q1 + Vector3(0, top - base, 0), q1, color.darkened(0.12))
				_tri(st, q0, q0 + Vector3(0, top - base, 0), q1 + Vector3(0, top - base, 0), color.darkened(0.12))
			else:
				_tri(st, q0, q1, q1 + Vector3(0, top - base, 0), color.darkened(0.12))
				_tri(st, q0, q1 + Vector3(0, top - base, 0), q0 + Vector3(0, top - base, 0), color.darkened(0.12))
		var idx := Geometry2D.triangulate_polygon(poly)
		var roof := color.lightened(0.05)
		for k in range(0, idx.size(), 3):
			var t0 := poly[idx[k]]
			var t1 := poly[idx[k + 1]]
			var t2 := poly[idx[k + 2]]
			var a := Vector3(t0.x, top, t0.y)
			var bb := Vector3(t1.x, top, t1.y)
			var cc := Vector3(t2.x, top, t2.y)
			if (t1 - t0).cross(t2 - t0) > 0.0:
				_tri(st, a, bb, cc, roof)
			else:
				_tri(st, a, cc, bb, roof)
	st.generate_normals()
	return st.commit()


func _grandstands_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for g in track.environment.grandstands:
		var line: PackedVector2Array = g["polyline"]
		var depth: float = g["depth"]
		for k in line.size() - 1:
			var a := line[k]
			var b := line[k + 1]
			var out := (b - a).normalized().orthogonal()  # away from the track (left of travel)
			var ha := terrain_height(a)
			var hb := terrain_height(b)
			var front_a := Vector3(a.x, ha + 1.0, a.y)
			var front_b := Vector3(b.x, hb + 1.0, b.y)
			var back_a := Vector3((a + out * depth).x, ha + 9.0, (a + out * depth).y)
			var back_b := Vector3((b + out * depth).x, hb + 9.0, (b + out * depth).y)
			st.set_uv(Vector2.ZERO)
			for v in [front_a, back_b, front_b, front_a, back_a, back_b]:
				st.add_vertex(v)
			for v in [front_a, front_b, front_b - Vector3(0, 1.2, 0), front_a, front_b - Vector3(0, 1.2, 0), front_a - Vector3(0, 1.2, 0)]:
				st.add_vertex(v)
	st.generate_normals()
	return st.commit()


# --- Pit building and start gantry -----------------------------------------------------------

func _pit_building() -> Node3D:
	var node := Node3D.new()
	node.name = "PitBuilding"
	var lane := track.pit_lane
	if lane.size() < 2:
		return node
	var asphalt := SurfaceTool.new()
	asphalt.begin(Mesh.PRIMITIVE_TRIANGLES)
	var building := SurfaceTool.new()
	building.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in lane.size() - 1:
		var a := lane[k]
		var b := lane[k + 1]
		var right := -(b - a).normalized().orthogonal()
		var h := geo.height_at(geo.project_local(a, maxi(0, _near_index(a)))) + 0.01
		var l0 := a - right * 5.0
		var r0 := a + right * 5.0
		var l1 := b - right * 5.0
		var r1 := b + right * 5.0
		for v in [Vector3(l0.x, h, l0.y), Vector3(l1.x, h, l1.y), Vector3(r1.x, h, r1.y), Vector3(l0.x, h, l0.y), Vector3(r1.x, h, r1.y), Vector3(r0.x, h, r0.y)]:
			asphalt.add_vertex(v)
		if k > 3 and k < lane.size() - 5:
			var f0 := a + right * 7.0
			var f1 := b + right * 7.0
			_box_between(building, f0, f1, right * 14.0, right * 14.0, h, h, 9.0)
	asphalt.generate_normals()
	_add(node, "PitLane", asphalt.commit(), _plain(Color(0.27, 0.28, 0.30), 0.85))
	_add(node, "Garages", building.commit(), _plain(Color(0.88, 0.89, 0.90), 0.6))
	return node


func _start_gantry() -> Node3D:
	var node := Node3D.new()
	node.name = "StartGantry"
	var i := track.start_index
	var p := track.data.points[i]
	var n := _normals[i]
	var h := track.data.heights[i]
	var t := (track.data.points[(i + 1) % track.data.points.size()] - p).normalized()
	var wl := track.data.width_left[i] + 2.0
	var wr := track.data.width_right[i] + 2.0
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for post in [p + n * wl, p - n * wr]:
		_box_between(st, post - t * 0.3, post + t * 0.3, n * 0.6, n * 0.6, h, h, 8.0)
	_box_between(st, p - n * wr - t * 0.4, p + n * wl - t * 0.4, t * 0.8, t * 0.8, h + 7.0, h + 7.0, 1.1)
	_add(node, "Frame", st.commit(), _plain(Color(0.15, 0.15, 0.17), 0.5))
	var lights := Node3D.new()
	lights.name = "StartLights"
	node.add_child(lights)
	for k in 5:
		var lamp := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.28
		sphere.height = 0.56
		lamp.mesh = sphere
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.2, 0.02, 0.02)
		mat.emission_enabled = true
		mat.emission = Color(1, 0.05, 0.02)
		mat.emission_energy_multiplier = 0.0  # off until the start procedure lights it
		lamp.material_override = mat
		var pos := p + n * (-2.0 + k * 1.0) - t * 0.5
		lamp.position = Vector3(pos.x, h + 7.55, pos.y)
		lights.add_child(lamp)
	return node


# --- Helpers ---------------------------------------------------------------------------------

func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	for v in [a, b, c]:
		st.set_color(color)
		st.add_vertex(v)


func _signed_area(poly: PackedVector2Array) -> float:
	var a := 0.0
	for k in poly.size():
		var p := poly[k]
		var q := poly[(k + 1) % poly.size()]
		a += p.x * q.y - q.x * p.y
	return a * 0.5


func _shader(shader: Shader) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader
	return m


func _plain(color: Color, roughness: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.cull_mode = BaseMaterial3D.CULL_DISABLED  # thin walls and flat strips must show from any side
	return m


func _vertex_color_material(roughness: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = roughness
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func _add(root: Node, node_name: String, mesh: Mesh, material: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.material_override = material
	root.add_child(mi)
	return mi
