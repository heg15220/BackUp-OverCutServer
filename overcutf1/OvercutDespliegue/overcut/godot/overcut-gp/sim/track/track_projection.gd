class_name TrackProjection
extends RefCounted
## Where a world position sits relative to the centreline.
## lateral is positive to the driver's LEFT; the left normal is tangent.orthogonal()
## because Godot's y axis points down.

var s := 0.0
var lateral := 0.0
var index := 0
## 0..1 position along segment `index`.
var t := 0.0
var tangent := Vector2.RIGHT
