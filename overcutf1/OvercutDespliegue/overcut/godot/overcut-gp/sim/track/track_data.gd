class_name TrackData
extends Resource
## A circuit as a closed centreline (metres, no repeated first point, spacing <= 5 m)
## plus per-point cross-section arrays parallel to `points`.
## "left"/"right" are from the driver's seat in the direction of travel.

@export var track_name := ""
@export var points := PackedVector2Array()
## Centre to edge of the asphalt.
@export var width_left := PackedFloat32Array()
@export var width_right := PackedFloat32Array()
## Kerb width beyond the asphalt edge (0 = none).
@export var kerb_left := PackedFloat32Array()
@export var kerb_right := PackedFloat32Array()
## 1 where the kerb is a high (sausage-style) kerb.
@export var kerb_high_left := PackedByteArray()
@export var kerb_high_right := PackedByteArray()
## Surface.Type between kerb and wall.
@export var runoff_left := PackedInt32Array()
@export var runoff_right := PackedInt32Array()
## Centre to wall.
@export var wall_left := PackedFloat32Array()
@export var wall_right := PackedFloat32Array()


func length() -> float:
	var total := 0.0
	var n := points.size()
	for i in n:
		total += points[i].distance_to(points[(i + 1) % n])
	return total
