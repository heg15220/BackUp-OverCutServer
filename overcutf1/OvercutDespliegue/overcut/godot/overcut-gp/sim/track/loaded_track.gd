class_name LoadedTrack
extends RefCounted
## A circuit as loaded from data/tracks/*.json (see TrackLoader).


class GridSlot:
	var position := Vector2.ZERO
	var heading := 0.0
	var index := 0


class Scenery:
	var lake := PackedVector2Array()
	var trees := PackedVector2Array()
	## [{footprint: PackedVector2Array, height: float}]
	var buildings: Array = []
	## [{kind: String, polygon: PackedVector2Array}]
	var parks: Array = []
	## [{polyline: PackedVector2Array, depth: float}]
	var grandstands: Array = []


var name := ""
var laps := 1
var start_index := 0
var data: TrackData
## Lateral offset of the racing line per centreline point (m, + = left).
var racing_line := PackedFloat32Array()
var grid: Array[GridSlot] = []
## [{detection_s, start_s, end_s}] in metres from the start line.
var drs_zones: Array = []
var sectors := PackedFloat32Array()
var pit_lane := PackedVector2Array()
var pit_entry_index := 0
var pit_exit_index := 0
var pit_speed_limit_kmh := 100.0
## DEM grid {x0, y0, step, nx, ny, heights}.
var terrain: Dictionary = {}
var environment: Scenery
