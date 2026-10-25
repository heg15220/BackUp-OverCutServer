class_name OverheadCamera
extends Camera3D
## High overhead camera in perspective, as in classic top-down racers: it follows the car
## from above and slightly behind, looking a little ahead of it. By default the view keeps
## a fixed orientation (north up, like the reference); `follow_heading` turns it with the car.

const HEIGHT_SLOW := 30.0
const HEIGHT_FAST := 46.0
const FAST_SPEED := 83.3
const TILT_BACK := 0.42  ## horizontal offset behind the target as a fraction of the height
const LOOK_AHEAD_S := 0.45
const LOOK_AHEAD_MAX := 32.0

@export var follow_heading := false
## Multiplies the camera height (settings zoom; dev captures).
@export var height_scale := 1.0

var target: CarVisual
var target_state: CarState
var _focus := Vector3.ZERO
var _yaw := 0.0


func _ready() -> void:
	fov = 50.0
	far = 2500.0


func snap() -> void:
	if target == null:
		return
	_focus = target.global_position
	_yaw = -target.rotation.y
	_place(1.0)


func _process(delta: float) -> void:
	if target == null or target_state == null:
		return
	var speed := target_state.speed()
	var fwd := Vector3(cos(-target.rotation.y), 0.0, sin(-target.rotation.y))
	var ahead := fwd * minf(speed * LOOK_AHEAD_S, LOOK_AHEAD_MAX)
	_focus = _focus.lerp(target.global_position + ahead, 1.0 - exp(-delta * 6.0))
	_yaw = lerp_angle(_yaw, -target.rotation.y, 1.0 - exp(-delta * 3.0))
	_place(clampf(speed / FAST_SPEED, 0.0, 1.0))


func _place(speed_frac: float) -> void:
	var h := lerpf(HEIGHT_SLOW, HEIGHT_FAST, speed_frac) * height_scale
	var view := get_viewport().get_visible_rect().size if is_inside_tree() else Vector2(16, 9)
	if view.y > view.x:
		h *= 1.35  # portrait: see further ahead and to the sides
	var back := Vector3(0.0, 0.0, h * TILT_BACK)  # north-up: camera sits to the south
	if follow_heading:
		back = -Vector3(cos(_yaw), 0.0, sin(_yaw)) * h * TILT_BACK
	global_position = _focus + back + Vector3(0.0, h, 0.0)
	look_at(_focus, Vector3.UP)  # never straight down (TILT_BACK > 0), so UP is a valid up vector
