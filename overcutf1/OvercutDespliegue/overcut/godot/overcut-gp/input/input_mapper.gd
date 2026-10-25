class_name InputMapper
extends RefCounted
## Turns keyboard, gamepad and touch into one DriverInput. Digital sources ramp
## (a key is either 0 or 1, a pedal is not) and digital/touch steering is reduced
## with speed so a full key press at 300 km/h does not throw the car off.

const THROTTLE_RAMP := 0.15  ## s from 0 to 1
const BRAKE_RAMP := 0.10
const STEER_RAMP := 0.20
const STEER_ATTENUATION_SPEED := 85.0  ## m/s where attenuation reaches its floor
const STEER_ATTENUATION_FLOOR := 0.35

const ACTIONS := {
	&"throttle": [KEY_W, KEY_UP, JOY_AXIS_TRIGGER_RIGHT],
	&"brake": [KEY_S, KEY_DOWN, JOY_AXIS_TRIGGER_LEFT],
	&"steer_left": [KEY_A, KEY_LEFT],
	&"steer_right": [KEY_D, KEY_RIGHT],
	&"kers": [KEY_SPACE, JOY_BUTTON_A],
	&"drs": [KEY_E, JOY_BUTTON_Y],
	&"shift_up": [KEY_Q, JOY_BUTTON_RIGHT_SHOULDER],
	&"shift_down": [KEY_Z, JOY_BUTTON_LEFT_SHOULDER],
}


## Raw control values before ramps and attenuation.
class Raw:
	var throttle := 0.0
	var brake := 0.0
	var steer := 0.0
	var throttle_digital := false
	var brake_digital := false
	var steer_digital := false
	var kers := false
	var drs := false
	var shift_up := false
	var shift_down := false


var assists := AssistConfig.new()
var _throttle := 0.0
var _brake := 0.0
var _steer := 0.0
var _prev_shift_up := false
var _prev_shift_down := false


## Registers the input actions in code so the bindings live in version control
## next to the mapper that reads them.
static func ensure_actions() -> void:
	for action in ACTIONS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action, 0.1)
		for code in ACTIONS[action]:
			var ev: InputEvent
			if action in [&"throttle", &"brake"] and code in [JOY_AXIS_TRIGGER_RIGHT, JOY_AXIS_TRIGGER_LEFT]:
				ev = InputEventJoypadMotion.new()
				ev.axis = code
				ev.axis_value = 1.0
			elif code in [JOY_BUTTON_A, JOY_BUTTON_Y, JOY_BUTTON_RIGHT_SHOULDER, JOY_BUTTON_LEFT_SHOULDER] and action in [&"kers", &"drs", &"shift_up", &"shift_down"]:
				ev = InputEventJoypadButton.new()
				ev.button_index = code
			else:
				ev = InputEventKey.new()
				ev.physical_keycode = code
			InputMap.action_add_event(action, ev)
	for side in [[&"steer_left", -1.0], [&"steer_right", 1.0]]:
		var stick := InputEventJoypadMotion.new()
		stick.axis = JOY_AXIS_LEFT_X
		stick.axis_value = side[1]
		InputMap.action_add_event(side[0], stick)


## Reads the live devices (keyboard/gamepad via the input map, plus touch).
func read(state: CarState, dt: float, touch: TouchControls = null) -> DriverInput:
	var r := Raw.new()
	var key_throttle := _key_pressed(&"throttle")
	var key_brake := _key_pressed(&"brake")
	var key_steer := (1.0 if _key_pressed(&"steer_right") else 0.0) - (1.0 if _key_pressed(&"steer_left") else 0.0)
	var pad_throttle := Input.get_action_strength(&"throttle") if not key_throttle else 0.0
	var pad_brake := Input.get_action_strength(&"brake") if not key_brake else 0.0
	var pad_steer := Input.get_axis(&"steer_left", &"steer_right") if key_steer == 0.0 else 0.0
	r.throttle = 1.0 if key_throttle else pad_throttle
	r.throttle_digital = key_throttle
	r.brake = 1.0 if key_brake else pad_brake
	r.brake_digital = key_brake
	r.steer = key_steer if key_steer != 0.0 else pad_steer
	r.steer_digital = key_steer != 0.0
	if touch != null:
		if touch.throttle > r.throttle:
			r.throttle = touch.throttle
			r.throttle_digital = false
		if touch.brake > r.brake:
			r.brake = touch.brake
			r.brake_digital = false
		if absf(touch.steer) > absf(r.steer):
			r.steer = touch.steer
			r.steer_digital = true  # touch is attenuated like a key, not ramped
	r.kers = Input.is_action_pressed(&"kers")
	r.drs = Input.is_action_pressed(&"drs")
	r.shift_up = Input.is_action_pressed(&"shift_up")
	r.shift_down = Input.is_action_pressed(&"shift_down")
	return process_raw(r, state, dt, touch != null and absf(touch.steer) > 0.0)


func process_raw(r: Raw, state: CarState, dt: float, steer_from_touch := false) -> DriverInput:
	_throttle = move_toward(_throttle, r.throttle, dt / THROTTLE_RAMP) if r.throttle_digital else r.throttle
	_brake = move_toward(_brake, r.brake, dt / BRAKE_RAMP) if r.brake_digital else r.brake
	if r.steer_digital and not steer_from_touch:
		_steer = move_toward(_steer, r.steer, dt / STEER_RAMP)
	else:
		_steer = r.steer
	var steer := _steer
	if r.steer_digital or assists.steer_assist:
		steer *= lerpf(1.0, STEER_ATTENUATION_FLOOR, clampf(state.speed() / STEER_ATTENUATION_SPEED, 0.0, 1.0))
	var out := DriverInput.new()
	out.throttle = clampf(_throttle, 0.0, 1.0)
	out.brake = clampf(_brake, 0.0, 1.0)
	out.steer = clampf(steer, -1.0, 1.0)
	out.kers = r.kers
	out.drs = r.drs
	# Gear changes fire on the press, not while held.
	out.shift_up = r.shift_up and not _prev_shift_up
	out.shift_down = r.shift_down and not _prev_shift_down
	_prev_shift_up = r.shift_up
	_prev_shift_down = r.shift_down
	return out


func _key_pressed(action: StringName) -> bool:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey and Input.is_physical_key_pressed(ev.physical_keycode):
			return true
	return false
