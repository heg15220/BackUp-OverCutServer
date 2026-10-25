class_name AiSkill
extends RefCounted
## How close to the limit an AI driver runs. Every level drives the same physics; a higher
## level uses more of the grip, brakes later, attacks and defends harder and errs less.

enum { BEGINNER, INTERMEDIATE, PROFESSIONAL, WORLD_CLASS, LEGEND }

const NAMES := ["Principiante", "Intermedio", "Profesional", "Clase mundial", "Leyenda"]
# level: [share of the profile speed, extra braking margin (m), aggression 0..1, mistakes per lap]
# The profile is an idealised limit (steady-state grip, perfect line); even a Legend keeps
# a few per cent in hand to stay on the road through kerbs, bumps and traffic.
const TABLE := [
	[0.80, 26.0, 0.25, 0.20],
	[0.84, 16.0, 0.45, 0.10],
	[0.87, 9.0, 0.65, 0.05],
	[0.90, 4.0, 0.85, 0.025],
	[0.93, 1.0, 1.00, 0.01],
]

var id := LEGEND
var pace := 1.0
var brake_margin := 0.0
var aggression := 1.0
var mistake_rate := 0.0


static func level(level_id: int) -> AiSkill:
	var s := AiSkill.new()
	var row: Array = TABLE[clampi(level_id, 0, TABLE.size() - 1)]
	s.id = level_id
	s.pace = row[0]
	s.brake_margin = row[1]
	s.aggression = row[2]
	s.mistake_rate = row[3]
	return s


## The same level adjusted for one driver (pace_delta: fraction faster, e.g. 0.004 = 0.4 %).
func for_driver(pace_delta: float) -> AiSkill:
	var s := AiSkill.new()
	s.id = id
	s.pace = clampf(pace * (1.0 + pace_delta), 0.6, 1.02)
	s.brake_margin = brake_margin
	s.aggression = aggression
	s.mistake_rate = mistake_rate
	return s
