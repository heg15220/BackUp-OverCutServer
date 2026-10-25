class_name ChaseCamera
extends Camera2D
## Overhead chase camera. By default it turns with the car so the nose always points
## up the screen (steering left is always screen-left, which suits touch controls);
## north_up keeps the map fixed instead. Zooms out with speed and looks ahead.

const ZOOM_STOPPED := 12.0  ## px per metre
const ZOOM_FAST := 6.5
const FAST_SPEED := 83.3  ## m/s (300 km/h)
const PORTRAIT_FACTOR := 0.8
const LOOK_AHEAD_S := 0.35
const LOOK_AHEAD_MAX := 25.0

@export var north_up := false

var follow: CarRenderer


func _ready() -> void:
	ignore_rotation = false
	zoom = Vector2.ONE * ZOOM_STOPPED


func _process(delta: float) -> void:
	if follow == null or follow.controller == null:
		return
	var state := follow.controller.state
	var speed := state.speed()
	var ahead := Vector2.from_angle(follow.rotation) * minf(speed * LOOK_AHEAD_S, LOOK_AHEAD_MAX)
	position = position.lerp(follow.position + ahead, 1.0 - exp(-delta * 8.0))
	var target_rot := 0.0 if north_up else follow.rotation + PI / 2
	rotation = lerp_angle(rotation, target_rot, 1.0 - exp(-delta * 6.0))
	var z := lerpf(ZOOM_STOPPED, ZOOM_FAST, clampf(speed / FAST_SPEED, 0.0, 1.0))
	var view := get_viewport_rect().size
	if view.y > view.x:
		z *= PORTRAIT_FACTOR
	zoom = zoom.lerp(Vector2.ONE * z, 1.0 - exp(-delta * 3.0))


func snap() -> void:
	if follow == null:
		return
	position = follow.position
	rotation = 0.0 if north_up else follow.rotation + PI / 2
