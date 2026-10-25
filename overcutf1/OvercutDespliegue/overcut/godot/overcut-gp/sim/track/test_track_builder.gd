class_name TestTrackBuilder
## Synthetic ~3.2 km clockwise test circuit: long straight, 90° corner with asphalt
## run-off, fast S, gravel hairpin, a high-kerb chicane and two closing corners.
## Two straights (main, heading east; return, heading north) are solved so the loop closes.

const SPACING := 4.0
const HALF_WIDTH := 6.0
const KERB := 1.5
const WALL := 20.0
const HAIRPIN_WALL := 35.0
const MAIN_STRAIGHT := 0
const RETURN_STRAIGHT := 14

enum Zone { NORMAL, ASPHALT_RUNOFF, HAIRPIN, CHICANE }

# [kind, length (S) or radius (A), angle (+ = right turn on screen), zone]; null = solved.
const SEGMENTS := [
	["S", null, 0.0, Zone.NORMAL],
	["A", 40.0, PI / 2, Zone.ASPHALT_RUNOFF],
	["S", 350.0, 0.0, Zone.NORMAL],
	["A", 180.0, 0.6108652, Zone.NORMAL],
	["A", 160.0, -0.6108652, Zone.NORMAL],
	["S", 150.0, 0.0, Zone.NORMAL],
	["A", 15.0, PI, Zone.HAIRPIN],
	["A", 60.0, -PI / 2, Zone.NORMAL],
	["S", 450.0, 0.0, Zone.NORMAL],
	["A", 30.0, -0.4363323, Zone.CHICANE],
	["A", 30.0, 0.8726646, Zone.CHICANE],
	["A", 30.0, -0.4363323, Zone.CHICANE],
	["S", 250.0, 0.0, Zone.NORMAL],
	["A", 50.0, PI / 2, Zone.NORMAL],
	["S", null, 0.0, Zone.NORMAL],
	["A", 60.0, PI / 2, Zone.NORMAL],
]


static func build() -> TrackData:
	var segs := SEGMENTS.duplicate(true)
	segs[MAIN_STRAIGHT][1] = 0.0
	segs[RETURN_STRAIGHT][1] = 0.0
	var end := _end_of(segs)
	segs[MAIN_STRAIGHT][1] = -end.x
	segs[RETURN_STRAIGHT][1] = end.y
	assert(segs[MAIN_STRAIGHT][1] > 0.0 and segs[RETURN_STRAIGHT][1] > 0.0, "test track does not close")

	var data := TrackData.new()
	data.track_name = "Circuito de pruebas"
	var pos := Vector2.ZERO
	var heading := 0.0
	for seg in segs:
		var length: float = seg[1] if seg[0] == "S" else seg[1] * absf(seg[2])
		var steps := maxi(1, ceili(length / SPACING))
		var dh: float = 0.0 if seg[0] == "S" else seg[2] / steps
		for k in steps:
			_append(data, pos, seg[3])
			# Exact chord of each arc step, so the polyline closes on itself.
			var chord: float = length / steps if dh == 0.0 else 2.0 * seg[1] * sin(absf(dh) * 0.5)
			pos += Vector2.from_angle(heading + dh * 0.5) * chord
			heading += dh
	return data


static func _end_of(segs: Array) -> Vector2:
	var pos := Vector2.ZERO
	var heading := 0.0
	for seg in segs:
		if seg[0] == "S":
			pos += Vector2.from_angle(heading) * float(seg[1])
		else:
			var r: float = seg[1]
			var a: float = seg[2]
			pos += Vector2.from_angle(heading + a * 0.5) * 2.0 * r * sin(absf(a) * 0.5)
			heading += a
	return pos


static func _append(data: TrackData, pos: Vector2, zone: int) -> void:
	data.points.append(pos)
	data.width_left.append(HALF_WIDTH)
	data.width_right.append(HALF_WIDTH)
	data.kerb_left.append(KERB)
	data.kerb_right.append(KERB)
	var high := 1 if zone == Zone.CHICANE else 0
	data.kerb_high_left.append(high)
	data.kerb_high_right.append(high)
	var runoff := Surface.Type.GRASS
	if zone == Zone.HAIRPIN:
		runoff = Surface.Type.GRAVEL
	elif zone == Zone.ASPHALT_RUNOFF:
		runoff = Surface.Type.RUNOFF_ASPHALT
	data.runoff_left.append(runoff)
	data.runoff_right.append(runoff)
	var wall := HAIRPIN_WALL if zone == Zone.HAIRPIN else WALL
	data.wall_left.append(wall)
	data.wall_right.append(wall)
