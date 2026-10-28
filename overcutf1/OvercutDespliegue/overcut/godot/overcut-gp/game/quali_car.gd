class_name QualiCar
extends RaceEntry
## One car in qualifying: where it is in its run (garage -> pit lane -> out-lap -> timed laps ->
## in-lap -> garage), the AI's plan of runs for the session, and its best time in each session.

enum Run { GARAGE, PIT_OUT, OUT_LAP, FLYING, IN_LAP, PIT_IN, OUT }

var run := Run.GARAGE
## Best valid lap of each session (the AI's with qualifying trim, track evolution and noise).
var times := [INF, INF, INF]
## Which sessions the car takes part in (knocked-out cars sit the rest out).
var in_session := [false, false, false]
var noise := [0.0, 0.0, 0.0]
## Estimated qualifying lap (Qualifying.estimated_lap x QUALI_TRIM), before evolution and noise.
var estimate := INF
## The garage: metres along the pit lane where the car stops.
var box_s := 0.0
## AI: [{start: session seconds, laps: timed laps}] for the current session.
var plan: Array = []
var plan_k := 0
var laps_left := 0
## The AI's skill on out- and in-laps.
var slow_skill: AiSkill
var lap_start := 0.0
var lap_valid := true
## The player left the garage this session (an untouched session takes their estimate).
var drove := false


## On the circuit itself (the AI's physics/kinematic stepping and the line apply).
func on_track() -> bool:
	return run == Run.OUT_LAP or run == Run.FLYING or run == Run.IN_LAP


## Out of the garage: on track or in the pit lane (the map and the name tags show it).
func out_of_garage() -> bool:
	return on_track() or run == Run.PIT_OUT or run == Run.PIT_IN
