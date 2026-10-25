class_name Minimap
extends Control
## Track outline with a dot per car (team colour; the player's car larger, ringed in white).

var points := PackedVector2Array()
## [{pos: Vector2, color: Color, player: bool}]
var cars: Array = []
var _min := Vector2.ZERO
var _scale := 1.0
var _offset := Vector2.ZERO


func set_track(track_points: PackedVector2Array) -> void:
	points = track_points
	_fit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_fit()


func _fit() -> void:
	if points.is_empty():
		return
	var lo := points[0]
	var hi := points[0]
	for p in points:
		lo = lo.min(p)
		hi = hi.max(p)
	var span := hi - lo
	var pad := 8.0
	_scale = minf((size.x - 2 * pad) / maxf(span.x, 1.0), (size.y - 2 * pad) / maxf(span.y, 1.0))
	_min = lo
	_offset = (size - span * _scale) * 0.5


func to_map(world: Vector2) -> Vector2:
	return (world - _min) * _scale + _offset


func _draw() -> void:
	if points.size() < 2:
		return
	var line := PackedVector2Array()
	for p in points:
		line.append(to_map(p))
	line.append(line[0])
	draw_polyline(line, Color(0, 0, 0, 0.55), 7.0, true)
	draw_polyline(line, Color(0.92, 0.93, 0.96), 3.0, true)
	draw_circle(line[0], 4.0, UiKit.ACCENT)
	for c in cars:
		if not c["player"]:
			draw_circle(to_map(c["pos"]), 4.5, c["color"])
	for c in cars:
		if c["player"]:
			var m := to_map(c["pos"])
			draw_circle(m, 7.5, Color.WHITE)
			draw_circle(m, 5.5, c["color"])
