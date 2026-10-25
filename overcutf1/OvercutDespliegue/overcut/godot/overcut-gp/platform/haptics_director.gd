class_name HapticsDirector
extends RefCounted
## Turns what the car feels into vibration: kerbs, lock-ups, wheelspin, going off
## track and impacts. One pattern per tick at most, at least MIN_GAP apart, except
## impacts, which always get through.

const MIN_GAP := 0.07
const IMPACT_THRESHOLD := 3.0  ## m/s of normal speed into a wall

enum Effect { OFFTRACK, LOCK, SPIN, KERB }

var enabled := true
## Seconds since this director started (tests timestamp pulses with it).
var time := 0.0

var _backends: Array[HapticsBackend]
var _last_pulse := -INF
## Effect -> seconds since it last fired (INF while inactive, so contact fires at once).
var _since := {Effect.OFFTRACK: INF, Effect.LOCK: INF, Effect.SPIN: INF, Effect.KERB: INF}


func _init(backends: Array[HapticsBackend]) -> void:
	_backends = backends


func update(state: CarState, input: DriverInput, dt: float) -> void:
	time += dt
	var impact := state.consume_impact()
	if not enabled:
		return
	if impact > IMPACT_THRESHOLD:
		_emit(clampf(impact / 25.0, 0.3, 1.0), mini(300, int(80.0 + 4.0 * impact)))

	var off := false
	var lock := false
	var spin := false
	var kerb_bump := 0.0
	for i in 4:
		var w := state.wheels[i]
		if w.surface == Surface.Type.GRASS or w.surface == Surface.Type.GRAVEL:
			off = true
		elif w.surface == Surface.Type.KERB_LOW or w.surface == Surface.Type.KERB_HIGH:
			kerb_bump = maxf(kerb_bump, Surface.bump(w.surface))
		if w.sliding and i < 2 and input.brake > 0.3:
			lock = true
		if w.sliding and i >= 2 and input.throttle > 0.3:
			spin = true

	# [effect, active, period, strength, duration], in priority order.
	var effects := [
		[Effect.OFFTRACK, off, 0.12, 0.6, 50],
		[Effect.LOCK, lock, 0.08, 0.5, 40],
		[Effect.SPIN, spin, 0.1, 0.4, 30],
		[Effect.KERB, kerb_bump > 0.0, clampf(6.0 / maxf(state.speed(), 0.1), 0.04, 0.2), 0.3 + 0.6 * kerb_bump, 25],
	]
	var fired := false
	for e in effects:
		if not e[1]:
			_since[e[0]] = INF
			continue
		_since[e[0]] += dt
		if fired or _since[e[0]] < e[2] - 1e-9 or time - _last_pulse < MIN_GAP - 1e-9:
			continue
		_emit(e[3], e[4])
		_since[e[0]] = 0.0
		fired = true


func _emit(strength: float, duration_ms: int) -> void:
	_last_pulse = time
	for b in _backends:
		b.pulse(strength, duration_ms)
