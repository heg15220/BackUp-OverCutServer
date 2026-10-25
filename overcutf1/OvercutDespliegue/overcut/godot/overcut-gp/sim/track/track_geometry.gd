class_name TrackGeometry
extends RefCounted
## Spatial queries over a TrackData: projection onto the centreline, surface lookup
## and wall contact. Segments are bucketed in a uniform grid for fast lookup.

const CELL := 5.0
const WHITE_LINE_WIDTH := 0.12
## Half-width of the rubbered racing-line band.
const RACING_LINE_HALF_WIDTH := 1.0
const MAX_RING := 20
## Segments searched behind/ahead of a hint (a car moves < 1 segment per tick).
const HINT_BACK := 3
const HINT_AHEAD := 5

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
	return _make_projection(best, best_t, pos)


## Projection when the caller knows roughly where it was last tick (a car's previous
## index): searches a few segments around the hint and falls back to the full search
## if the nearest one sits at the edge of that window.
func project_hinted(pos: Vector2, hint: int) -> TrackProjection:
	var best := -1
	var best_k := 0
	var best_d2 := INF
	var best_t := 0.0
	var pts := data.points
	# Inlined closest-point loop: this runs for every car every tick.
	for k in HINT_BACK + HINT_AHEAD + 1:
		var i := (hint - HINT_BACK + k + _n) % _n
		var a := pts[i]
		var ab := pts[(i + 1) % _n] - a
		var len2 := ab.length_squared()
		var t := 0.0 if len2 == 0.0 else clampf((pos - a).dot(ab) / len2, 0.0, 1.0)
		var d2 := (a + ab * t).distance_squared_to(pos)
		if d2 < best_d2:
			best_d2 = d2
			best_t = t
			best = i
			best_k = k
	var at_edge := (best_k == 0 and best_t <= 0.0) or (best_k == HINT_BACK + HINT_AHEAD and best_t >= 1.0)
	# Beyond the walls the local minimum may belong to another part of the circuit.
	var reach := maxf(data.wall_left[best], data.wall_right[best]) + 5.0
	if at_edge or best_d2 > reach * reach:
		return project(pos)
	var p := _make_projection(best, best_t, pos)
	# Off the racing surface another part of the circuit may be nearer than the
	# hinted one (two legs sharing an infield), so ask the full search.
	var left := p.lateral >= 0.0
	var edge := _side(data.width_left if left else data.width_right, p) + _side(data.kerb_left if left else data.kerb_right, p)
	if absf(p.lateral) > edge:
		return project(pos)
	return p


## Lateral offset of a nearby point (within a car length of p), walking to the
## neighbouring segment when the point lies past either end of p's segment, so it
## follows the curve instead of extrapolating p's tangent.
func lateral_at(p: TrackProjection, pos: Vector2) -> float:
	var i := p.index
	var a := data.points[i]
	var ab := data.points[(i + 1) % _n] - a
	var t := 0.0
	for walk in 3:
		a = data.points[i]
		ab = data.points[(i + 1) % _n] - a
		var len2 := ab.length_squared()
		t = 0.0 if len2 == 0.0 else (pos - a).dot(ab) / len2
		if t > 1.0:
			i = (i + 1) % _n
		elif t < 0.0:
			i = (i - 1 + _n) % _n
		else:
			break
	t = clampf(t, 0.0, 1.0)
	return (pos - (a + ab * t)).dot(ab.normalized().orthogonal())


func surface_at(pos: Vector2, racing_line_lateral := INF) -> int:
	var p := project(pos)
	return surface_for(p, p.lateral, racing_line_lateral)


## Surface at `lateral` across the track at projection p's position along it.
func surface_for(p: TrackProjection, lateral: float, racing_line_lateral := INF) -> int:
	var left := lateral >= 0.0
	var d := absf(lateral)
	var width := _side(data.width_left if left else data.width_right, p)
	if d <= width - WHITE_LINE_WIDTH:
		if absf(lateral - racing_line_lateral) <= RACING_LINE_HALF_WIDTH:
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
	var pen := wall_penetration(p, p.lateral, radius)
	if pen <= 0.0:
		return Vector2.ZERO
	return inward_normal(p, p.lateral) * pen


## How deep a circle at `lateral` reaches past the wall on its side (0 if clear).
func wall_penetration(p: TrackProjection, lateral: float, radius: float) -> float:
	var wall := _side(data.wall_left if lateral >= 0.0 else data.wall_right, p)
	return maxf(0.0, absf(lateral) + radius - wall)


## Unit vector pointing from the wall on `lateral`'s side back towards the centreline.
func inward_normal(p: TrackProjection, lateral: float) -> Vector2:
	return p.tangent.orthogonal() * (-1.0 if lateral >= 0.0 else 1.0)


func _make_projection(index: int, t: float, pos: Vector2) -> TrackProjection:
	if t >= 1.0:
		# A vertex belongs to the segment that starts there.
		index = (index + 1) % _n
		t = 0.0
	var a := data.points[index]
	var b := data.points[(index + 1) % _n]
	var p := TrackProjection.new()
	p.index = index
	p.t = t
	p.tangent = (b - a).normalized()
	p.s = lerpf(_cumulative[index], _cumulative[index + 1], t)
	p.lateral = (pos - a.lerp(b, t)).dot(p.tangent.orthogonal())
	return p


func _side(arr: PackedFloat32Array, p: TrackProjection) -> float:
	return lerpf(arr[p.index], arr[(p.index + 1) % _n], p.t)


## Returns (squared distance, t along segment).
func _closest_on_segment(i: int, pos: Vector2) -> Vector2:
	var a := data.points[i]
	var ab := data.points[(i + 1) % _n] - a
	var len2 := ab.length_squared()
	var t := 0.0 if len2 == 0.0 else clampf((pos - a).dot(ab) / len2, 0.0, 1.0)
	return Vector2((a + ab * t).distance_squared_to(pos), t)
