class_name CarContacts
## Car-to-car contact: three circles per car along its axis. Overlaps are pushed apart and
## an impulse with low restitution and some friction is exchanged at the contact point.

const CIRCLES := [1.6, 0.0, -1.6]
const RADIUS := 0.85
const RESTITUTION := 0.2
const FRICTION := 0.3
const BROAD := 6.0  ## centres farther apart than this cannot touch


static func resolve(cars: Array[CarState], specs: Array) -> void:
	for sweep in 2:
		for a in cars.size():
			for b in range(a + 1, cars.size()):
				var ca := cars[a]
				var cb := cars[b]
				if ca.position.distance_squared_to(cb.position) > BROAD * BROAD:
					continue
				_pair(ca, cb, specs[a], specs[b])


static func _pair(a: CarState, b: CarState, sa: CarSpec, sb: CarSpec) -> void:
	var ma := sa.mass_kg + a.fuel_kg
	var mb := sb.mass_kg + b.fuel_kg
	for xa in CIRCLES:
		for xb in CIRCLES:
			var ra := Vector2(xa, 0.0).rotated(a.heading)
			var rb := Vector2(xb, 0.0).rotated(b.heading)
			var pa := a.position + ra
			var pb := b.position + rb
			var d := pa.distance_to(pb)
			var pen := 2.0 * RADIUS - d
			if pen <= 0.0:
				continue
			var n := (pb - pa) / d if d > 1e-4 else Vector2.RIGHT.rotated(a.heading).orthogonal()
			var total := ma + mb
			a.position -= n * pen * (mb / total)
			b.position += n * pen * (ma / total)
			var va := a.velocity + ra.rotated(PI / 2) * a.yaw_rate
			var vb := b.velocity + rb.rotated(PI / 2) * b.yaw_rate
			var vn := (vb - va).dot(n)
			if vn >= 0.0:
				continue
			var rna := ra.x * n.y - ra.y * n.x
			var rnb := rb.x * n.y - rb.y * n.x
			var j := -(1.0 + RESTITUTION) * vn / (1.0 / ma + 1.0 / mb + rna * rna / sa.yaw_inertia + rnb * rnb / sb.yaw_inertia)
			var impulse := n * j
			var t_rel := (vb - va) - n * vn
			if t_rel.length() > 0.01:
				impulse += -t_rel.normalized() * minf(FRICTION * j, t_rel.length() * 0.5 * total)
			a.velocity -= impulse / ma
			b.velocity += impulse / mb
			a.yaw_rate -= (ra.x * impulse.y - ra.y * impulse.x) / sa.yaw_inertia
			b.yaw_rate += (rb.x * impulse.y - rb.y * impulse.x) / sb.yaw_inertia
			a.last_impact_speed = maxf(a.last_impact_speed, -vn)
			b.last_impact_speed = maxf(b.last_impact_speed, -vn)
