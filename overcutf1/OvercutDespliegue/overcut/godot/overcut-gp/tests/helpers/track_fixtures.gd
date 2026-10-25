class_name TrackFixtures
## Test tracks. oval(): a 1000 m straight from (0,0) heading +x, then a 300 m-radius
## loop back. On the first straight the driver's right is +y (Godot y-down).

const STRAIGHT := 1000.0
const RADIUS := 300.0


static func oval(runoff := Surface.Type.GRASS, kerb := 1.5, kerb_high := false, wall := 20.0, half_width := 6.0) -> TrackData:
	var d := TrackData.new()
	d.track_name = "Óvalo de pruebas"
	var pts := PackedVector2Array()
	for i in int(STRAIGHT / 4.0):
		pts.append(Vector2(i * 4.0, 0.0))
	var arc_steps := int(PI * RADIUS / 4.0)
	for i in arc_steps:
		var a := -PI / 2 + PI * i / arc_steps
		pts.append(Vector2(STRAIGHT, RADIUS) + Vector2.from_angle(a) * RADIUS)
	for i in int(STRAIGHT / 4.0):
		pts.append(Vector2(STRAIGHT - i * 4.0, 2.0 * RADIUS))
	for i in arc_steps:
		var a := PI / 2 + PI * i / arc_steps
		pts.append(Vector2(0.0, RADIUS) + Vector2.from_angle(a) * RADIUS)
	d.points = pts
	for p in pts:
		d.width_left.append(half_width)
		d.width_right.append(half_width)
		d.kerb_left.append(kerb)
		d.kerb_right.append(kerb)
		d.kerb_high_left.append(1 if kerb_high else 0)
		d.kerb_high_right.append(1 if kerb_high else 0)
		d.runoff_left.append(runoff)
		d.runoff_right.append(runoff)
		d.wall_left.append(wall)
		d.wall_right.append(wall)
	return d


## A car on the first straight at lateral offset `right_m` (positive = right), heading +x.
static func car_on_straight(spec: CarSpec, x: float, right_m: float, speed_ms: float, heading := 0.0) -> CarState:
	var s := SimRunner.rolling(spec, speed_ms)
	s.position = Vector2(x, right_m)
	s.heading = heading
	s.velocity = Vector2.from_angle(heading) * speed_ms
	return s
