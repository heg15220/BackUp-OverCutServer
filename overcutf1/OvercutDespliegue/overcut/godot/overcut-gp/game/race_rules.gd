class_name RaceRules
## Sporting rules of the season (2012 for now): points, race distances, the user's
## mandatory compound change, the 107 % rule and penalty sizes.

enum Length { LAPS_3, LAPS_5, PERCENT_25, PERCENT_50 }

const LENGTH_NAMES := ["3 vueltas", "5 vueltas", "25 % de la carrera", "50 % de la carrera"]
const WET_COMPOUNDS := [&"intermediate", &"wet"]
## A jump start is a drive-through; served as its typical time loss at Albert Park.
const JUMP_START_PENALTY_S := 20.0
const SC_OVERTAKE_PENALTY_S := 10.0
const DRS_GAP_S := 1.0
## DRS opens two laps after the start (2012).
const DRS_FROM_LAP := 3


static func points_for(position: int, table: Array) -> int:
	return int(table[position - 1]) if position >= 1 and position <= table.size() else 0


static func race_laps(real_laps: int, length: int) -> int:
	match length:
		Length.LAPS_3:
			return 3
		Length.LAPS_5:
			return 5
		Length.PERCENT_25:
			return ceili(real_laps * 0.25)
		_:
			return ceili(real_laps * 0.5)


static func mandatory_stop(length: int) -> bool:
	return length == Length.PERCENT_25 or length == Length.PERCENT_50


## The user's rule for 25 % and 50 % races: at least one stop that fits a compound other than
## the one the car started on (afterwards any compound is fine). Wet races are exempt.
static func stop_rule_ok(start_compound: StringName, fitted: Array, mandatory: bool) -> bool:
	if not mandatory or start_compound in WET_COMPOUNDS:
		return true
	for c in fitted:
		if c != start_compound or c in WET_COMPOUNDS:
			return true
	return false


static func within_107(lap_time: float, best_q1: float) -> bool:
	return lap_time <= best_q1 * 1.07
