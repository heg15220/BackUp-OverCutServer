class_name EngineAudio
extends Node3D
## The weekend's engine sound, as on a TV broadcast: the player's engine up front and the
## nearest rivals (by distance, on their side of the screen, with Doppler as they pass).
## EngineVoice renders two seamless loops once (on and off the throttle, at REF_RPM); every
## engine is that pair played back at rpm / REF_RPM and crossfaded by the load, so the
## per-frame cost is a few property writes and Godot's own mixer does the rest (on the web
## too, where it plays them as samples). Players pause with the scene tree.

const LOOP_RATE := 44100.0
## 12 000 rpm is a 100 Hz engine cycle: exactly 441 samples, so the loops close seamlessly.
const REF_RPM := 12000.0
const LOOP_CYCLES := 40
const MAX_RIVALS := 3
const HEARING_RANGE := 180.0
const PLAYER_DB := -8.0
const RIVAL_DB := -4.0
const SPEED_OF_SOUND := 343.0

static var _loops: Array = []  ## [AudioStreamWAV on, AudioStreamWAV off]

var _mine: Array = []  ## [AudioStreamPlayer on, off]
var _rivals: Array = []  ## MAX_RIVALS x [AudioStreamPlayer3D on, off]
var _cars: Array = []
var _listener_pos := Vector2.ZERO
var _listener_vel := Vector2.ZERO
var _heights := {}  ## code -> height, for placing the 3D players


func _ready() -> void:
	if _loops.is_empty():
		_loops = [_bake_loop(1.0), _bake_loop(0.0)]
	for k in 2:
		var p := AudioStreamPlayer.new()
		p.stream = _loops[k]
		add_child(p)
		_mine.append(p)
	for r in MAX_RIVALS:
		var pair := []
		for k in 2:
			var p := AudioStreamPlayer3D.new()
			p.stream = _loops[k]
			p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED  # distance_gain() does it
			p.panning_strength = 1.0
			add_child(p)
			pair.append(p)
		_rivals.append(pair)


## The cars to hear this frame: [{code, pos, vel, height, rpm, load, player}].
func set_cars(listener_pos: Vector2, listener_vel: Vector2, cars: Array) -> void:
	_listener_pos = listener_pos
	_listener_vel = listener_vel
	_cars = cars


func _process(_delta: float) -> void:
	var rivals := []
	for c in _cars:
		if c["player"]:
			_drive(_mine, c["rpm"], c["load"], db_to_linear(PLAYER_DB), 1.0)
		elif c["pos"].distance_to(_listener_pos) < HEARING_RANGE:
			rivals.append(c)
	if not _cars.any(func(c): return c["player"]):
		_drive(_mine, REF_RPM, 0.0, 0.0, 1.0)
	rivals.sort_custom(func(a, b): return a["pos"].distance_squared_to(_listener_pos) < b["pos"].distance_squared_to(_listener_pos))
	for r in MAX_RIVALS:
		var pair: Array = _rivals[r]
		if r >= rivals.size():
			_drive(pair, REF_RPM, 0.0, 0.0, 1.0)
			continue
		var c: Dictionary = rivals[r]
		for p in pair:
			p.global_position = Vector3(c["pos"].x, c["height"], c["pos"].y)
		var gain := db_to_linear(RIVAL_DB) * distance_gain(c["pos"].distance_to(_listener_pos))
		_drive(pair, c["rpm"], c["load"], gain, doppler(_listener_pos, _listener_vel, c["pos"], c["vel"]))


## One engine: both loops at the engine's pitch, crossfaded by the load (equal power).
func _drive(pair: Array, rpm: float, load: float, gain: float, pitch: float) -> void:
	var scale := clampf(rpm / REF_RPM * pitch, 0.2, 3.5)
	var weights := [sqrt(clampf(load, 0.0, 1.0)), sqrt(1.0 - clampf(load, 0.0, 1.0))]
	for k in 2:
		var p = pair[k]
		var g: float = gain * weights[k]
		if g < 0.001:
			if p.playing:
				p.stop()
			continue
		p.pitch_scale = scale
		p.volume_db = linear_to_db(g)
		if not p.playing:
			p.play(randf() * 0.2)  # rivals sharing a loop never start in phase


## One seamless loop of the synthesised engine at REF_RPM, as 16-bit mono.
static func _bake_loop(load: float) -> AudioStreamWAV:
	var cycle := int(LOOP_RATE * 120.0 / REF_RPM)
	var frames := cycle * LOOP_CYCLES
	var v := EngineVoice.new()
	var warm := PackedVector2Array()
	warm.resize(cycle * 4)
	v.render(warm, LOOP_RATE, REF_RPM, load, 1.0, 0.0, 1.0)  # settles the filter
	var buf := PackedVector2Array()
	buf.resize(frames)
	v.render(buf, LOOP_RATE, REF_RPM, load, 1.0, 0.0, 1.0)
	var data := PackedByteArray()
	data.resize(frames * 2)
	for i in frames:
		data.encode_s16(i * 2, int(clampf(buf[i].x, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = int(LOOP_RATE)
	wav.stereo = false
	wav.data = data
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = frames
	return wav


## Loudness of a rival at d metres (a TV microphone's falloff, silent past HEARING_RANGE).
static func distance_gain(d: float) -> float:
	if d >= HEARING_RANGE:
		return 0.0
	return 1.0 / (1.0 + pow(d / 15.0, 2.0)) * (1.0 - d / HEARING_RANGE)


## Doppler pitch factor of a source heard by a moving listener.
static func doppler(listener_pos: Vector2, listener_vel: Vector2, source_pos: Vector2, source_vel: Vector2) -> float:
	var to_listener := listener_pos - source_pos
	if to_listener.length() < 0.5:
		return 1.0
	var dir := to_listener.normalized()
	var source_toward := source_vel.dot(dir)
	var listener_toward := -listener_vel.dot(dir)
	return clampf((SPEED_OF_SOUND + listener_toward) / (SPEED_OF_SOUND - source_toward), 0.6, 1.6)


## Revs of a car that has no engine state (kinematic cars): the highest gear that keeps the
## engine in its power band at this speed.
static func rpm_for_speed(spec: CarSpec, speed: float) -> float:
	var per_rpm := TAU / 60.0 * spec.tyre_radius
	for g in range(spec.gear_ratios.size(), 0, -1):
		var rpm := speed / per_rpm * spec.gear_ratios[g - 1]
		if rpm >= Powertrain.DOWNSHIFT_TARGET_RPM * 0.75:
			return minf(rpm, Powertrain.UPSHIFT_RPM)
	return clampf(speed / per_rpm * spec.gear_ratios[0], spec.idle_rpm, Powertrain.UPSHIFT_RPM)
