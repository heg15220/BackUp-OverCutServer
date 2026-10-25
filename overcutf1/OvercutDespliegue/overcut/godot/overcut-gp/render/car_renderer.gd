class_name CarRenderer
extends Node2D
## Top-down 2012 F1 car at real scale (about 5.0 x 1.8 m), drawn procedurally in team
## colours only: wide front wing, stepped "platypus" nose, coke-bottle sidepods,
## engine-cover fin, narrow 750 mm rear wing, wider rear tyres. Car points along +x.

const TYRE := Color(0.07, 0.07, 0.08)
const CARBON := Color(0.12, 0.12, 0.13)
const SHADOW := Color(0, 0, 0, 0.32)
## Pirelli 2012 sidewall colours.
const COMPOUND_COLORS := {
	&"supersoft": Color(0.86, 0.08, 0.10), &"soft": Color(0.98, 0.82, 0.10),
	&"medium": Color(0.95, 0.95, 0.95), &"hard": Color(0.70, 0.72, 0.75),
	&"intermediate": Color(0.20, 0.70, 0.30), &"wet": Color(0.15, 0.45, 0.90),
}

@export var primary := Color(0.86, 0.04, 0.04)
@export var secondary := Color(0.95, 0.95, 0.95)
@export var helmet := Color(0.98, 0.85, 0.10)

var controller: CarController


func _process(_delta: float) -> void:
	if controller == null:
		return
	var alpha := Engine.get_physics_interpolation_fraction()
	position = controller.interpolated_position(alpha)
	rotation = controller.interpolated_heading(alpha)
	queue_redraw()


func _draw() -> void:
	var steer := controller.state.steer_angle if controller != null else 0.0
	var compound: StringName = controller.state.wheels[0].tyre.compound.id if controller != null else &"medium"
	draw_set_transform(Vector2(0.14, 0.2).rotated(-rotation), 0.0, Vector2.ONE)
	_body(true, 0.0, compound)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_body(false, steer, compound)


func _body(shadow: bool, steer: float, compound: StringName) -> void:
	var c_tyre := SHADOW if shadow else TYRE
	var c_main := SHADOW if shadow else primary
	var c_second := SHADOW if shadow else secondary
	var c_carbon := SHADOW if shadow else CARBON
	var stripe: Color = SHADOW if shadow else COMPOUND_COLORS.get(compound, Color.WHITE)

	# Suspension arms
	if not shadow:
		for y in [-1.0, 1.0]:
			draw_line(Vector2(1.95, 0.22 * y), Vector2(1.84, 0.72 * y), c_carbon, 0.05)
			draw_line(Vector2(1.6, 0.25 * y), Vector2(1.84, 0.72 * y), c_carbon, 0.05)
			draw_line(Vector2(-1.2, 0.3 * y), Vector2(-1.56, 0.70 * y), c_carbon, 0.05)

	# Rear tyres (wider), front tyres (steered)
	for y in [-0.71, 0.71]:
		_tyre(Vector2(-1.56, y), Vector2(0.66, 0.38), 0.0, c_tyre, stripe, y)
		_tyre(Vector2(1.84, y * 1.06), Vector2(0.66, 0.29), steer, c_tyre, stripe, y)

	# Floor and sidepods (coke bottle)
	draw_colored_polygon(PackedVector2Array([
		Vector2(0.95, -0.30), Vector2(0.75, -0.66), Vector2(-0.55, -0.68), Vector2(-1.35, -0.36),
		Vector2(-1.35, 0.36), Vector2(-0.55, 0.68), Vector2(0.75, 0.66), Vector2(0.95, 0.30),
	]), c_main)
	# Monocoque and stepped nose: wide chassis, then the step, then the narrow nose.
	draw_colored_polygon(PackedVector2Array([
		Vector2(2.38, -0.11), Vector2(1.55, -0.17), Vector2(1.5, -0.27), Vector2(0.2, -0.31),
		Vector2(0.2, 0.31), Vector2(1.5, 0.27), Vector2(1.55, 0.17), Vector2(2.38, 0.11),
	]), c_main)
	if not shadow:
		draw_line(Vector2(1.52, -0.22), Vector2(1.52, 0.22), c_main.darkened(0.35), 0.04)  # the nose step
		draw_colored_polygon(PackedVector2Array([Vector2(2.38, -0.11), Vector2(2.2, -0.12), Vector2(2.2, 0.12), Vector2(2.38, 0.11)]), c_second)
	# Engine cover tapering to the gearbox, with the shark fin
	draw_colored_polygon(PackedVector2Array([
		Vector2(0.25, -0.24), Vector2(-1.9, -0.12), Vector2(-2.15, -0.08),
		Vector2(-2.15, 0.08), Vector2(-1.9, 0.12), Vector2(0.25, 0.24),
	]), c_main)
	if not shadow:
		draw_line(Vector2(0.05, 0.0), Vector2(-2.05, 0.0), c_second, 0.05)
		# Cockpit opening and helmet
		draw_colored_polygon(PackedVector2Array([Vector2(0.95, -0.2), Vector2(0.15, -0.22), Vector2(0.15, 0.22), Vector2(0.95, 0.2)]), CARBON)
		draw_circle(Vector2(0.48, 0.0), 0.14, helmet)
		draw_line(Vector2(0.56, -0.08), Vector2(0.56, 0.08), Color(0.1, 0.1, 0.1), 0.04)  # visor
	# Front wing (1.8 m) with endplates
	draw_rect(Rect2(2.22, -0.9, 0.3, 1.8), c_main)
	draw_rect(Rect2(2.22, -0.9, 0.3, 0.06), c_second)
	draw_rect(Rect2(2.22, 0.84, 0.3, 0.06), c_second)
	if not shadow:
		draw_line(Vector2(2.34, -0.86), Vector2(2.34, 0.86), c_second, 0.03)
	# Rear wing (750 mm) with endplates
	draw_rect(Rect2(-2.48, -0.375, 0.32, 0.75), c_second)
	draw_rect(Rect2(-2.48, -0.375, 0.32, 0.05), c_main)
	draw_rect(Rect2(-2.48, 0.325, 0.32, 0.05), c_main)


func _tyre(center: Vector2, size: Vector2, angle: float, body: Color, stripe: Color, side: float) -> void:
	draw_set_transform(center, angle, Vector2.ONE)
	draw_rect(Rect2(-size * 0.5, size), body)
	# Coloured sidewall band on the outer edge shows the compound.
	var y_edge := size.y * 0.5 - 0.04 if side > 0 else -size.y * 0.5
	draw_rect(Rect2(-size.x * 0.32, y_edge, size.x * 0.64, 0.04), stripe)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
