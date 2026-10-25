class_name TrackEnvironment
extends RefCounted
## Track geometry plus the conditions the cars feel. geometry == null means an
## infinite flat asphalt plane (used by dynamics tests).

var geometry: TrackGeometry
var air_c := 22.0
var track_c := 32.0
var water := 0.0


static func flat() -> TrackEnvironment:
	return TrackEnvironment.new()


static func on(track: TrackData) -> TrackEnvironment:
	var env := TrackEnvironment.new()
	env.geometry = TrackGeometry.new(track)
	return env


func surface_at(pos: Vector2) -> int:
	if geometry == null:
		return Surface.Type.ASPHALT
	return geometry.surface_at(pos)


## Uniform for now; the weekend plan replaces this with a puddle/drying field.
func water_at(_pos: Vector2) -> float:
	return water
