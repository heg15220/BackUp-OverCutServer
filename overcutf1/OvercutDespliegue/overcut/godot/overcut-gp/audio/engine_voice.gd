class_name EngineVoice
extends RefCounted
## One synthesised 2012 F1 V8 (2.4 l, 18 000 rpm): a wavetable holding one engine cycle (two
## crank turns, eight firing pulses of slightly different strength, which gives the rasp),
## read at rpm / 120 cycles per second. A bright table on the throttle and a soft, quieter one
## off it, a little exhaust noise, and a one-pole low-pass that opens with the load.
## Parameters glide across each buffer so gear changes and pans never click.

const TABLE_SIZE := 1024
const CYLINDERS := 8
const NOISE_SIZE := 4096
const OFF_LEVEL := 0.45

static var _on := PackedFloat32Array()
static var _off := PackedFloat32Array()
static var _noise := PackedFloat32Array()

var _phase := 0.0
var _noise_i := 0
var _lp := 0.0
var _rpm := -1.0
var _load := 0.0
var _gain := 0.0
var _pan := 0.0
var _pitch := 1.0


func _init() -> void:
	if _on.is_empty():
		_build_tables()


## Fades the voice in from silence the next time it renders (a rival coming into earshot).
func restart() -> void:
	_gain = 0.0


## Adds `out.size()` frames of this engine to `out` (stereo). pan: -1 left .. 1 right;
## pitch multiplies the frequency (Doppler). The output stays within +-gain.
func render(out: PackedVector2Array, rate: float, rpm: float, load: float, gain: float, pan: float, pitch: float) -> void:
	var n := out.size()
	if n == 0:
		return
	if _rpm < 0.0:
		_rpm = rpm
		_load = load
		_pitch = pitch
		_pan = pan
	var inv := 1.0 / n
	var d_rpm := (rpm - _rpm) * inv
	var d_load := (load - _load) * inv
	var d_gain := (gain - _gain) * inv
	var d_pan := (pan - _pan) * inv
	var d_pitch := (pitch - _pitch) * inv
	var size_f := float(TABLE_SIZE)
	for i in n:
		_rpm += d_rpm
		_load += d_load
		_gain += d_gain
		_pan += d_pan
		_pitch += d_pitch
		_phase += _rpm / 120.0 * _pitch / rate
		_phase -= floorf(_phase)
		var x := _phase * size_f
		var k := int(x)
		var f := x - k
		var k2 := (k + 1) % TABLE_SIZE
		var on := lerpf(_on[k], _on[k2], f)
		var off := lerpf(_off[k], _off[k2], f)
		_noise_i = (_noise_i + 1) % NOISE_SIZE
		var raw := lerpf(off, on, _load) * 0.85 + _noise[_noise_i] * (0.05 + 0.1 * _load)
		_lp += (raw - _lp) * (0.3 + 0.55 * _load)
		var v := _lp * _gain
		out[i] += Vector2(v * minf(1.0, 1.0 - _pan), v * minf(1.0, 1.0 + _pan))


static func _build_tables() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2012
	var strength := []
	for c in CYLINDERS:
		strength.append(rng.randf_range(0.88, 1.0))
	_on.resize(TABLE_SIZE)
	_off.resize(TABLE_SIZE)
	for i in TABLE_SIZE:
		var p := float(i) / TABLE_SIZE * CYLINDERS
		var c := int(p)
		var t := p - c  # 0..1 inside this cylinder's firing slot
		var a: float = strength[c]
		# On the throttle: a sharp, ringing pressure pulse; off it: a soft thump.
		_on[i] = a * exp(-t * 5.0) * sin(TAU * t * 2.0)
		_off[i] = a * exp(-t * 2.5) * sin(TAU * t)
	_normalise(_on, 1.0)
	_normalise(_off, OFF_LEVEL)
	_noise.resize(NOISE_SIZE)
	for i in NOISE_SIZE:
		_noise[i] = rng.randf_range(-1.0, 1.0)


## Removes the DC offset and scales the peak to `peak`.
static func _normalise(table: PackedFloat32Array, peak: float) -> void:
	var mean := 0.0
	for v in table:
		mean += v
	mean /= table.size()
	var top := 0.0
	for i in table.size():
		table[i] -= mean
		top = maxf(top, absf(table[i]))
	for i in table.size():
		table[i] *= peak / top
