class_name TouchControls
extends Control
## On-screen pedals and steering. Each finger keeps the zone it first touched until
## it lifts, even if it slides out (thumbs drift on glass). Values are progressive:
## pedals by how high the finger is, steering by how far to the outer edge.

enum Zone { NONE, STEER_LEFT, STEER_RIGHT, BRAKE, THROTTLE }

const PEDAL_DEADZONE := 0.08
const STEER_INNER := 0.35
## Zone layout as fractions of the control's size: x, y, w, h.
const LAYOUT := {
	Zone.STEER_LEFT: Rect2(0.0, 0.6, 0.15, 0.4),
	Zone.STEER_RIGHT: Rect2(0.15, 0.6, 0.15, 0.4),
	Zone.BRAKE: Rect2(0.70, 0.6, 0.15, 0.4),
	Zone.THROTTLE: Rect2(0.85, 0.6, 0.15, 0.4),
}
const COLORS := {
	Zone.STEER_LEFT: Color(1, 1, 1, 0.16),
	Zone.STEER_RIGHT: Color(1, 1, 1, 0.16),
	Zone.BRAKE: Color(0.88, 0.02, 0.0, 0.28),
	Zone.THROTTLE: Color(0.0, 0.78, 0.35, 0.28),
}

@export var layout_scale := 1.0
@export var layout_offset := Vector2.ZERO

var throttle := 0.0
var brake := 0.0
var steer := 0.0
## finger index -> [zone, value]
var _fingers := {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		handle_touch(event.index, event.position - global_position, event.pressed)
	elif event is InputEventScreenDrag:
		handle_drag(event.index, event.position - global_position)


func zone_rect(zone: int) -> Rect2:
	var f: Rect2 = LAYOUT[zone]
	var r := Rect2(f.position * size, f.size * size)
	var grown := r.size * layout_scale
	return Rect2(r.position + (r.size - grown) * Vector2(0.5, 1.0) + layout_offset, grown)


func zone_at(pos: Vector2) -> int:
	for zone in LAYOUT:
		if zone_rect(zone).has_point(pos):
			return zone
	return Zone.NONE


## 0 at the bottom edge, 1 at the top, with a dead zone at the bottom.
func pedal_value(local_y: float, height: float) -> float:
	var v := clampf(1.0 - local_y / height, 0.0, 1.0)
	return 0.0 if v < PEDAL_DEADZONE else (v - PEDAL_DEADZONE) / (1.0 - PEDAL_DEADZONE)


## Magnitude from STEER_INNER at the edge facing the other button to 1 at the outer edge.
func steer_value(local_x: float, width: float, is_right: bool) -> float:
	var outward := clampf(local_x / width, 0.0, 1.0)
	if not is_right:
		outward = 1.0 - outward
	return lerpf(STEER_INNER, 1.0, outward)


func handle_touch(index: int, pos: Vector2, pressed: bool) -> void:
	if pressed:
		var zone := zone_at(pos)
		if zone == Zone.NONE:
			return
		_fingers[index] = [zone, 0.0]
		handle_drag(index, pos)
	else:
		_fingers.erase(index)
		_recompute()


func handle_drag(index: int, pos: Vector2) -> void:
	if not _fingers.has(index):
		return
	var zone: int = _fingers[index][0]
	var r := zone_rect(zone)
	var local := pos - r.position
	var value: float
	match zone:
		Zone.BRAKE, Zone.THROTTLE:
			value = pedal_value(local.y, r.size.y)
		Zone.STEER_LEFT:
			value = -steer_value(local.x, r.size.x, false)
		Zone.STEER_RIGHT:
			value = steer_value(local.x, r.size.x, true)
	_fingers[index][1] = value
	_recompute()


func _recompute() -> void:
	throttle = 0.0
	brake = 0.0
	steer = 0.0
	for f in _fingers.values():
		match f[0]:
			Zone.THROTTLE:
				throttle = maxf(throttle, f[1])
			Zone.BRAKE:
				brake = maxf(brake, f[1])
			Zone.STEER_LEFT, Zone.STEER_RIGHT:
				steer += f[1]
	steer = clampf(steer, -1.0, 1.0)
	queue_redraw()


func _draw() -> void:
	for zone in LAYOUT:
		var r := zone_rect(zone)
		draw_rect(r.grow(-6.0), COLORS[zone], true)
		var active := false
		for f in _fingers.values():
			active = active or f[0] == zone
		if active:
			draw_rect(r.grow(-6.0), Color(1, 1, 1, 0.5), false, 3.0)
