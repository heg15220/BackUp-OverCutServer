class_name RecordingHaptics
extends HapticsBackend
## Test double: records every pulse as [strength, duration_ms].

var pulses: Array = []


func pulse(strength: float, duration_ms: int) -> void:
	pulses.append([strength, duration_ms])
