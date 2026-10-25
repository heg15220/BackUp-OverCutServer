class_name RaceEntry
extends RefCounted
## One car in a session: who drives it, its physics state, lap and tyre bookkeeping.

enum Status { RUNNING, PIT, RETIRED, FINISHED }

var code := ""
var driver: Dictionary
var team: Dictionary
var spec: CarSpec
var state: CarState
var is_player := false
var ai: AiDriver
var profile: SpeedProfile
var skill: AiSkill
var grid_position := 0

var status := Status.RUNNING
var retire_reason := ""
## Lap 1 starts when the car first crosses the line (the grid is behind it).
var laps_done := -1
var lap_progress := 0.0  ## metres along the centreline from the line
var lap_start_time := -1.0
var last_lap := 0.0
var best_lap := INF
var finish_time := 0.0
var penalty_s := 0.0

var start_compound := &"soft"
var fitted: Array = []  ## compounds fitted at each stop
var pit_plan_lap := -1
var pit_requested := false
var pit_compound := &"medium"

## Physics (near the camera) or kinematic (following the line at its calibrated pace).
var physics := true
var kin_index := 0
var kin_t := 0.0
var kin_v := 0.0
## Pit lane progress (metres) while status == PIT; stationary time left in the box.
var pit_s := 0.0
var pit_wait := 0.0
var pit_stopped := false
var drs_eligible := false


func progress_total(track_length: float) -> float:
	return laps_done * track_length + lap_progress


func retire(reason: String, _time: float) -> void:
	if status == Status.FINISHED:
		return
	status = Status.RETIRED
	retire_reason = reason
	state.velocity = Vector2.ZERO
	state.yaw_rate = 0.0


func compound() -> StringName:
	return state.wheels[0].tyre.compound.id
