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


# --- kinematic mode (shared by the race and qualifying) --------------------------------

const KIN_ACCEL := 14.0
const KIN_DECEL := 38.0


## Follows the profile's line, easing kin_v toward target (m/s), and writes the pose to state.
func advance_on_line(track: LoadedTrack, target: float, dt: float) -> void:
	var n := profile.points.size()
	kin_v = move_toward(kin_v, target, (KIN_ACCEL if target > kin_v else KIN_DECEL) * dt)
	var travel := kin_v * dt
	while travel > 0.0:
		var seg := profile.ds[kin_index]
		var left := seg * (1.0 - kin_t)
		if travel < left:
			kin_t += travel / seg
			travel = 0.0
		else:
			travel -= left
			kin_t = 0.0
			kin_index = (kin_index + 1) % n
	var a := profile.points[kin_index]
	var b := profile.points[(kin_index + 1) % n]
	var jitter := (float(grid_position % 5) - 2.0) * 0.4  # cars side by side never sit on one line
	var tangent := (b - a).normalized()
	state.position = a.lerp(b, kin_t) + tangent.orthogonal() * jitter
	state.heading = tangent.angle()
	state.velocity = tangent * kin_v
	state.height = lerpf(track.data.heights[kin_index], track.data.heights[(kin_index + 1) % n], kin_t)
	state.track_index = kin_index
	state.distance_m += kin_v * dt


## Hands the car between the full physics and the kinematic line-follower.
func switch_mode(to_physics: bool, geo: TrackGeometry) -> void:
	physics = to_physics
	if to_physics:
		var tangent := (profile.points[(kin_index + 1) % profile.points.size()] - profile.points[kin_index]).normalized()
		state.velocity = tangent * kin_v
		state.yaw_rate = 0.0
		state.track_index = kin_index
	else:
		var pr := geo.project_hinted(state.position, maxi(state.track_index, 0))
		kin_index = pr.index
		kin_t = pr.t
		kin_v = state.speed()
