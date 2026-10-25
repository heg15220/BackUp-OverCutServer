class_name CarModel2012
## Procedural 3D model of a 2012 Formula One car, built from the FIA 2012 technical
## regulations and each team's chassis parameters (data/seasons/2012.json "car").
##
## Envelope (2012 rules): overall width 1800 mm, front wing 1800 mm, rear wing 750 mm wide,
## max height 950 mm, chassis top <= 625 mm and the nose <= 550 mm from 1950 mm ahead of the
## cockpit (hence the "platypus" step), front overhang <= 1200 mm, rear overhang <= 600 mm,
## Pirelli tyres 660 mm diameter, 245 mm wide front and 325 mm rear.
##
## Local space: +X forward, +Y up, +Z to the car's right; origin on the ground under the
## centre of gravity (46 % of the wheelbase behind the front axle), matching the physics.

const TYRE_RADIUS := 0.33
const FRONT_TYRE_WIDTH := 0.245
const REAR_TYRE_WIDTH := 0.325
const HALF_WIDTH := 0.9
const CHASSIS_TOP := 0.625
const SMOOTH_CHASSIS_TOP := 0.56  ## cars without a step (McLaren) ran a low chassis
const CG_FROM_FRONT := 0.54  ## fraction of the wheelbase from front axle to CG
const CARBON := Color(0.09, 0.09, 0.10)
const COCKPIT := Color(0.03, 0.03, 0.035)


class WheelSpec:
	var position := Vector3.ZERO
	var width := 0.0
	var front := false


static func front_axle_x(team: Dictionary) -> float:
	return CG_FROM_FRONT * float(team["car"]["wheelbase"])


static func rear_axle_x(team: Dictionary) -> float:
	return front_axle_x(team) - float(team["car"]["wheelbase"])


static func nose_step_height(team: Dictionary) -> float:
	return float(team["car"]["nose_step"])


static func wheel_layout(team: Dictionary) -> Array[WheelSpec]:
	var out: Array[WheelSpec] = []
	for front in [true, true, false, false]:
		var w := WheelSpec.new()
		w.front = front
		w.width = FRONT_TYRE_WIDTH if front else REAR_TYRE_WIDTH
		var side := -1.0 if out.size() % 2 == 0 else 1.0
		w.position = Vector3(front_axle_x(team) if front else rear_axle_x(team), TYRE_RADIUS, side * (HALF_WIDTH - w.width * 0.5))
		out.append(w)
	return out


## The bodywork (everything but the wheels) as one vertex-coloured mesh.
static func build_body(team: Dictionary) -> ArrayMesh:
	var car: Dictionary = team["car"]
	var primary := Color(team["colors"]["primary"])
	var secondary := Color(team["colors"]["secondary"])
	var accent := Color(team["colors"]["accent"])
	var fa := front_axle_x(team)
	var ra := rear_axle_x(team)
	var step := float(car["nose_step"])
	var chassis_top := CHASSIS_TOP if step > 0.0 else SMOOTH_CHASSIS_TOP
	var nose_top := chassis_top - step
	var tip := float(car["nose_tip"])
	var sidepod := float(car["sidepod"])

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Monocoque and nose: [x, half width bottom, half width top, y bottom, y top]
	var step_x := fa - 0.05
	_loft(st, [
		[fa + 0.98, 0.09, 0.06, tip - 0.11, tip],
		[fa + 0.55, 0.13, 0.10, tip - 0.16, tip + 0.06],
		[step_x + 0.001, 0.19, 0.16, 0.17, nose_top],
		[step_x, 0.21, 0.19, 0.14, chassis_top],
		[fa - 0.75, 0.30, 0.25, 0.06, chassis_top],
		[fa - 1.55, 0.32, 0.27, 0.06, chassis_top - 0.02],
	], primary)
	_loft(st, [[fa + 0.99, 0.092, 0.062, tip - 0.11, tip + 0.002], [fa + 0.80, 0.11, 0.08, tip - 0.13, tip + 0.03]], secondary)

	# Sidepods: wide at the radiator inlets, pulled in at the "coke bottle" before the gearbox.
	var sp_front := fa - 0.85
	_loft(st, [
		[sp_front, 0.60, 0.52, 0.06, 0.52],
		[sp_front - sidepod * 0.55, 0.62, 0.50, 0.06, 0.57],
		[sp_front - sidepod, 0.34, 0.22, 0.06, 0.46],
		[ra - 0.20, 0.17, 0.12, 0.12, 0.36],
	], primary)
	_loft(st, [[sp_front + 0.01, 0.605, 0.525, 0.30, 0.50], [sp_front - 0.05, 0.62, 0.53, 0.30, 0.52]], CARBON)  # inlet

	# Engine cover and airbox (above the driver's head), tapering to the gearbox.
	_loft(st, [
		[fa - 1.55, 0.17, 0.11, 0.50, 0.93],
		[fa - 2.05, 0.20, 0.09, 0.45, 0.86],
		[ra + 0.40, 0.12, 0.05, 0.35, 0.56],
		[ra - 0.12, 0.08, 0.04, 0.30, 0.42],
	], primary)
	_box(st, Vector3(fa - 1.58, 0.86, 0.0), Vector3(0.04, 0.10, 0.17), COCKPIT)  # airbox intake
	if bool(car["fin"]):
		_loft(st, [[fa - 1.95, 0.008, 0.008, 0.80, 0.86], [ra - 0.10, 0.008, 0.008, 0.40, 0.80]], primary)

	# Floor
	_box(st, Vector3((fa - 0.6 + ra + 0.2) * 0.5, 0.04, 0.0), Vector3((fa - 0.6) - (ra + 0.2), 0.02, 1.40), CARBON)

	# Cockpit opening, helmet and mirrors
	_box(st, Vector3(fa - 1.15, chassis_top + 0.004, 0.0), Vector3(0.75, 0.01, 0.40), COCKPIT)
	var helmet: Dictionary = team.get("helmet", {"main": "#F5D100", "stripe": "#1E3A8A"})
	_sphere(st, Vector3(fa - 1.25, chassis_top + 0.04, 0.0), 0.13, Color(helmet["main"]))
	_box(st, Vector3(fa - 1.17, chassis_top + 0.06, 0.0), Vector3(0.02, 0.05, 0.20), Color(helmet["stripe"]))  # visor band
	for side in [-1.0, 1.0]:
		_box(st, Vector3(fa - 0.72, 0.70, side * 0.40), Vector3(0.06, 0.04, 0.12), primary)

	# Front wing (1800 mm): main plane, flap, endplates
	_box(st, Vector3(fa + 0.93, 0.085, 0.0), Vector3(0.38, 0.03, 1.79), secondary)
	_box(st, Vector3(fa + 0.80, 0.14, 0.0), Vector3(0.18, 0.05, 1.70), primary)
	for side in [-1.0, 1.0]:
		_box(st, Vector3(fa + 0.88, 0.16, side * 0.893), Vector3(0.48, 0.22, 0.014), accent)

	# Rear wing (750 mm): main plane, flap, beam wing, endplates, pillar
	var rw_x := ra - 0.40
	_box(st, Vector3(rw_x, 0.72, 0.0), Vector3(0.32, 0.04, 0.74), secondary)
	_box(st, Vector3(rw_x + 0.06, 0.83, 0.0), Vector3(0.20, 0.05, 0.74), primary)
	_box(st, Vector3(rw_x, 0.38, 0.0), Vector3(0.24, 0.03, 0.70), CARBON)
	for side in [-1.0, 1.0]:
		_box(st, Vector3(rw_x, 0.65, side * 0.368), Vector3(0.40, 0.60, 0.014), accent)
	_box(st, Vector3(ra - 0.25, 0.55, 0.0), Vector3(0.06, 0.34, 0.03), CARBON)

	# Suspension wishbones from the chassis to the wheel centres
	for w in wheel_layout(team):
		var inner_z := 0.22 if w.front else 0.20
		var reach := absf(w.position.z) - inner_z
		var z := signf(w.position.z) * (inner_z + reach * 0.5)
		_box(st, Vector3(w.position.x, 0.42, z), Vector3(0.05, 0.025, reach), CARBON)
		_box(st, Vector3(w.position.x, 0.25, z), Vector3(0.05, 0.025, reach), CARBON)

	return st.commit()


## Lofts rectangular-ish cross-sections [x, hw_bottom, hw_top, y_bottom, y_top] along X,
## with flat outward normals (computed per face, so winding never matters).
static func _loft(st: SurfaceTool, sections: Array, color: Color, z := 0.0) -> void:
	var rings: Array = []
	for s in sections:
		var x: float = s[0]
		rings.append([Vector3(x, s[3], z - s[1]), Vector3(x, s[3], z + s[1]), Vector3(x, s[4], z + s[2]), Vector3(x, s[4], z - s[2])])
	var centre := Vector3.ZERO
	for r in rings:
		for v in r:
			centre += v
	centre /= rings.size() * 4.0
	for i in rings.size() - 1:
		var a: Array = rings[i]
		var b: Array = rings[i + 1]
		for k in 4:
			_quad(st, a[k], a[(k + 1) % 4], b[(k + 1) % 4], b[k], centre, color)
	_quad(st, rings[0][0], rings[0][1], rings[0][2], rings[0][3], centre, color)
	var last: Array = rings[-1]
	_quad(st, last[0], last[1], last[2], last[3], centre, color)


static func _box(st: SurfaceTool, centre: Vector3, size: Vector3, color: Color) -> void:
	var h := size * 0.5
	_loft(st, [[centre.x - h.x, h.z, h.z, centre.y - h.y, centre.y + h.y], [centre.x + h.x, h.z, h.z, centre.y - h.y, centre.y + h.y]], color, centre.z)


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, inside: Vector3, color: Color) -> void:
	var n := (b - a).cross(c - a)
	if n.length_squared() < 1e-12:
		n = (c - a).cross(d - a)
	if n.length_squared() < 1e-12:
		return
	n = n.normalized()
	var face := (a + b + c + d) * 0.25
	if n.dot(face - inside) < 0.0:
		n = -n
	# Godot treats clockwise triangles (seen from outside) as front faces, so each
	# triangle is wound against the outward normal.
	for tri in [[a, b, c], [a, c, d]]:
		var v0: Vector3 = tri[0]
		var v1: Vector3 = tri[1]
		var v2: Vector3 = tri[2]
		var tn := (v1 - v0).cross(v2 - v0)
		if tn.length_squared() < 1e-14:
			continue
		if tn.dot(n) > 0.0:
			var tmp := v1
			v1 = v2
			v2 = tmp
		for v in [v0, v1, v2]:
			st.set_color(color)
			st.set_normal(n)
			st.add_vertex(v)


static func _sphere(st: SurfaceTool, centre: Vector3, r: float, color: Color) -> void:
	var rings := 6
	var segs := 10
	for i in rings:
		var t0 := PI * i / rings
		var t1 := PI * (i + 1) / rings
		for j in segs:
			var p0 := TAU * j / segs
			var p1 := TAU * (j + 1) / segs
			var v := [Vector3(sin(t0) * cos(p0), cos(t0), sin(t0) * sin(p0)), Vector3(sin(t0) * cos(p1), cos(t0), sin(t0) * sin(p1)),
				Vector3(sin(t1) * cos(p1), cos(t1), sin(t1) * sin(p1)), Vector3(sin(t1) * cos(p0), cos(t1), sin(t1) * sin(p0))]
			_quad(st, centre + v[0] * r, centre + v[1] * r, centre + v[2] * r, centre + v[3] * r, centre, color)
