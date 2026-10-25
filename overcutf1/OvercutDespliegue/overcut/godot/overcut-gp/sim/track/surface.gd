class_name Surface
## Grip, rolling resistance and roughness of every surface a wheel can touch.
## The water term here is the surface's own (paint, grass); tyre-in-water is TyreState's job.

enum Type { ASPHALT, RACING_LINE, KERB_LOW, KERB_HIGH, WHITE_LINE, GRASS, GRAVEL, RUNOFF_ASPHALT, PIT_LANE, WALL }

# Type: [grip dry, grip at water 1.0, rolling resistance, bump]
const _TABLE := {
	Type.ASPHALT: [1.00, 1.00, 0.015, 0.0],
	Type.RACING_LINE: [1.03, 0.97, 0.015, 0.0],
	Type.KERB_LOW: [0.92, 0.70, 0.02, 0.35],
	Type.KERB_HIGH: [0.78, 0.55, 0.05, 0.9],
	Type.WHITE_LINE: [0.97, 0.55, 0.015, 0.0],
	Type.GRASS: [0.40, 0.25, 0.08, 0.4],
	Type.GRAVEL: [0.35, 0.30, 0.60, 0.7],
	Type.RUNOFF_ASPHALT: [0.95, 0.90, 0.016, 0.0],
	Type.PIT_LANE: [0.95, 0.90, 0.015, 0.0],
	Type.WALL: [0.30, 0.30, 0.5, 1.0],
}


static func grip(type: int, water: float) -> float:
	var row: Array = _TABLE[type]
	return lerpf(row[0], row[1], clampf(water, 0.0, 1.0))


static func rolling_resistance(type: int) -> float:
	return _TABLE[type][2]


static func bump(type: int) -> float:
	return _TABLE[type][3]


static func is_off_track(type: int) -> bool:
	return type == Type.GRASS or type == Type.GRAVEL or type == Type.WALL
