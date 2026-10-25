class_name TrackGeometry
extends RefCounted
## Spatial queries over a TrackData: projection onto the centreline, surface lookup
## and wall contact. Segments are bucketed in a uniform grid for fast lookup.

const CELL := 25.0
const WHITE_LINE_WIDTH := 0.12
## Half-width of the rubbered racing-line band.
const RACING_LINE_HALF_WIDTH := 1.0
const MAX_RING := 4

var data: TrackData
var _n := 0
var _cumulative := PackedFloat32Array()
var _grid := {}


func _init(track: TrackData) -> void:
	data = track
	_n = track.points.size()
	_cumulative.resize(_n + 1)
	for i in _n:
		var a := track.points[i]
		var b := track.points[(i + 1) % _n]
		_cumulative[i + 1] = _cumulative[i] + a.distance_to(b)
		var lo := Vector2i(floori(minf(a.x, b.x) / CELL), floori(minf(a.y, b.y) / CELL))
		var hi := Vector2i(floori(maxf(a.x, b.x) / CELL), floori(maxf(a.y, b.y) / CELL))
		for cx in range(lo.x, hi.x + 1):
			for cy in range(lo.y, hi.y + 1):
				var key := Vector2i(cx, cy)
				if not _grid.has(key):
					_grid[key] = PackedInt32Array()
				_grid[key].append(i)


func length() -> float:
	return _cumulative[_n]


func project(pos: Vector2) -> TrackProjection:
	# Search rings of cells around pos. A segment closer than `ring * CELL` must
	# touch a cell within that ring, so the search can stop once the best hit is
	# inside the radius already covered.
	var key := Vector2i(floori(pos.x / CELL), floori(pos.y / CELL))
	var best := -1
	var best_d2 := INF
	var best_t := 0.0
	var ring := 1
	while ring <= MAX_RING:
		for cx in range(key.x - ring, key.x + ring + 1):
			for cy in range(key.y - ring, key.y + ring + 1):
				if ring > 1 and absi(cx - key.x) < ring and absi(cy - key.y) < ring:
					continue  # inner cells were searched by the previous ring
				var cell: Variant = _grid.get(Vector2i(cx, cy))
				if cell == null:
					continue
				for i in cell:
					var r := _closest_on_segment(i, pos)
					if r.x < best_d2:
						best_d2 = r.x
						best_t = r.y
						best = i
		if best >= 0 and best_d2 <= pow(ring * CELL, 2):
			break
		ring += 1
	if best < 0 or best_d2 > pow(MAX_RING * CELL, 2):
		for i in _n:
			var r := _closest_on_segment(i, pos)
			if r.x < best_d2:
				best_d2 = r.x
				best_t = r.y
				best = i
	if best_t >= 1.0:
		# A vertex belongs to the segment that starts there.
		best = (best + 1) % _n
		best_t = 0.0
	var a := data.points[best]
	var b := data.points[(best + 1) % _n]
	var p := TrackProjection.new()
	p.index = best
	p.t = best_t
	p.tangent = (b - a).normalized()
	p.s = lerpf(_cumulative[best], _cumulative[best + 1], best_t)
	p.lateral = (pos - a.lerp(b, best_t)).dot(p.tangent.orthogonal())
	return p


func surface_at(pos: Vector2, racing_line_lateral := INF) -> int:
	var p := project(pos)
	var left := p.lateral >= 0.0
	var d := absf(p.lateral)
	var width := _side(data.width_left if left else data.width_right, p)
	if d <= width - WHITE_LINE_WIDTH:
		if absf(p.lateral - racing_line_lateral) <= RACING_LINE_HALF_WIDTH:
			return Surface.Type.RACING_LINE
		return Surface.Type.ASPHALT
	if d <= width:
		return Surface.Type.WHITE_LINE
	var kerb := _side(data.kerb_left if left else data.kerb_right, p)
	if d <= width + kerb:
		var high := (data.kerb_high_left if left else data.kerb_high_right)[p.index]
		return Surface.Type.KERB_HIGH if high == 1 else Surface.Type.KERB_LOW
	if d < _side(data.wall_left if left else data.wall_right, p):
		return (data.runoff_left if left else data.runoff_right)[p.index]
	return Surface.Type.WALL


## Penetration vector (depth * inward normal) of a circle against the wall, or ZERO.
func wall_contact(pos: Vector2, radius: float) -> Vector2:
	var p := project(pos)
	var left := p.lateral >= 0.0
	var wall := _side(data.wall_left if left else data.wall_right, p)
	var pen := absf(p.lateral) + radius - wall
	if pen <= 0.0:
		return Vector2.ZERO
	var outward := p.tangent.orthogonal() * (1.0 if left else -1.0)
	return -outward * pen


func _side(arr: PackedFloat32Array, p: TrackProjection) -> float:
	return lerpf(arr[p.index], arr[(p.index + 1) % _n], p.t)


## Returns (squared distance, t along segment).
func _closest_on_segment(i: int, pos: Vector2) -> Vector2:
	var a := data.points[i]
	var ab := data.points[(i + 1) % _n] - a
	var len2 := ab.length_squared()
	var t := 0.0 if len2 == 0.0 else clampf((pos - a).dot(ab) / len2, 0.0, 1.0)
	return Vector2((a + ab * t).distance_squared_to(pos), t)
