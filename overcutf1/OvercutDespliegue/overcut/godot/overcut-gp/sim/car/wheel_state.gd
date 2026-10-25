class_name WheelState
extends RefCounted
## One wheel's tyre plus the last substep's contact telemetry (forces in the wheel frame).

var tyre: TyreState
var load_n := 0.0
var slip_angle := 0.0
var slip_ratio := 0.0  ## estimated; +-1 while sliding
var sliding := false
var surface := Surface.Type.ASPHALT
## Grip available this substep (N); assists read it to stay under the limit.
var avail_n := 0.0
var fx := 0.0
var fy := 0.0
