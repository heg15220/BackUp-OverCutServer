class_name DriverInput
extends RefCounted
## What a driver (human or AI) asks of the car for one tick.

var throttle := 0.0  ## 0..1
var brake := 0.0  ## 0..1
var steer := 0.0  ## -1..1, negative = left
var kers := false
var drs := false
var shift_up := false
var shift_down := false


func copy() -> DriverInput:
	var c := DriverInput.new()
	c.throttle = throttle
	c.brake = brake
	c.steer = steer
	c.kers = kers
	c.drs = drs
	c.shift_up = shift_up
	c.shift_down = shift_down
	return c
