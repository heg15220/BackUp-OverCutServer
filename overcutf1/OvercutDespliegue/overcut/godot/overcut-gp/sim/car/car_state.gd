class_name CarState
extends RefCounted
## Dynamic state of one car. World frame: metres, Godot's y axis down, heading 0 = +x,
## positive heading/yaw = clockwise on screen (a right turn).
## Car frame: x forward, y to the RIGHT. That keeps the textbook vehicle-dynamics
## formulas valid in Godot's y-down space.

const FL := 0
const FR := 1
const RL := 2
const RR := 3

var position := Vector2.ZERO
var heading := 0.0
var velocity := Vector2.ZERO
var yaw_rate := 0.0
var steer_angle := 0.0  ## rad at the wheel, positive = right
var fuel_kg := 0.0
var drs_open := false
var auto_gearbox := true
var powertrain: Powertrain
var wheels: Array[WheelState] = []
## Acceleration in the car frame during the last substep (feeds load transfer, telemetry, haptics).
var accel_local := Vector2.ZERO
var last_impact_speed := 0.0
var wall_contact := false
var distance_m := 0.0
## Last track segment index (hint for the next projection); -1 = unknown.
var track_index := -1


static func create(spec: CarSpec, compound_id: StringName, tyre_temp_c: float) -> CarState:
	var s := CarState.new()
	s.powertrain = Powertrain.new(spec)
	for i in 4:
		var w := WheelState.new()
		w.tyre = TyreState.fresh(compound_id, tyre_temp_c)
		s.wheels.append(w)
	return s


func speed() -> float:
	return velocity.length()


func forward() -> Vector2:
	return Vector2.from_angle(heading)


## x forward, y to the right.
func local_velocity() -> Vector2:
	return velocity.rotated(-heading)


func consume_impact() -> float:
	var v := last_impact_speed
	last_impact_speed = 0.0
	return v
