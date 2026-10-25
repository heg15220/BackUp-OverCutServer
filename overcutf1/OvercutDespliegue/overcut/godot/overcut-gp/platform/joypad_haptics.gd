class_name JoypadHaptics
extends HapticsBackend
## Gamepad rumble on every connected pad. In the browser it also asks the Gamepad
## API's vibrationActuator directly, which works where Godot's own call does not.

const WEAK_RATIO := 0.6


func pulse(strength: float, duration_ms: int) -> void:
	var s := clampf(strength, 0.0, 1.0)
	for device in Input.get_connected_joypads():
		Input.start_joy_vibration(device, s * WEAK_RATIO, s, duration_ms / 1000.0)
	if OS.has_feature("web"):
		JavaScriptBridge.eval(
			"(navigator.getGamepads ? Array.from(navigator.getGamepads()) : []).forEach(function (g) {"
			+ " if (g && g.vibrationActuator) g.vibrationActuator.playEffect('dual-rumble',"
			+ " {duration: %d, strongMagnitude: %f, weakMagnitude: %f}); });" % [duration_ms, s, s * WEAK_RATIO])
