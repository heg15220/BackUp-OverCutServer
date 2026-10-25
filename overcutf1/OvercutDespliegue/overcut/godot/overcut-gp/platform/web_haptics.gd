class_name WebHaptics
extends HapticsBackend
## Phone/tablet vibration through the browser's navigator.vibrate. Android browsers
## support it; iOS Safari has no web vibration API, so this is silent there.
## The API has no intensity, so weaker pulses are made shorter.


func pulse(strength: float, duration_ms: int) -> void:
	if not OS.has_feature("web"):
		return
	var ms := maxi(10, int(duration_ms * (0.5 + 0.5 * clampf(strength, 0.0, 1.0))))
	JavaScriptBridge.eval("navigator.vibrate && navigator.vibrate(%d)" % ms)
