class_name SimClock
extends RefCounted
## Fixed-step accumulator: turns variable frame times into whole 120 Hz ticks.
## A long hitch never integrates a big dt; it runs at most MAX_TICKS_PER_FRAME
## ticks and drops the rest (the game slows down instead of exploding).

const TICK := 1.0 / 120.0
const MAX_TICKS_PER_FRAME := 8

var _accumulator := 0.0


func advance(frame_dt: float) -> int:
	_accumulator += maxf(0.0, frame_dt)
	var ticks := floori((_accumulator + 1e-9) / TICK)
	_accumulator -= ticks * TICK
	if ticks > MAX_TICKS_PER_FRAME:
		ticks = MAX_TICKS_PER_FRAME
		_accumulator = 0.0
	return ticks


## Fraction of a tick left over, for interpolating what is drawn.
func alpha() -> float:
	return clampf(_accumulator / TICK, 0.0, 1.0)
