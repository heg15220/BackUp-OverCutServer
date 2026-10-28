extends TestCase
## The synthesised V8: its pitch follows the revs, it is louder on the throttle, and the
## mix places rivals by distance, side and Doppler like a TV broadcast.

const RATE := 22050.0


func _render(rpm: float, load: float, gain := 1.0, seconds := 0.5) -> PackedVector2Array:
	var v := EngineVoice.new()
	var out := PackedVector2Array()
	out.resize(int(RATE * seconds))
	v.render(out, RATE, rpm, load, gain, 0.0, 1.0)
	return out


## Firing frequency from the autocorrelation of the left channel (skips the first 0.1 s).
func _firing_hz(buf: PackedVector2Array, lo_hz: float, hi_hz: float) -> float:
	var x := PackedFloat32Array()
	for i in range(int(RATE * 0.1), buf.size()):
		x.append(buf[i].x)
	# Normalised autocorrelation; the first lag within 90 % of the best is the period (its
	# multiples correlate almost as well and would read as a sub-harmonic).
	var lags := range(int(RATE / hi_hz), int(RATE / lo_hz) + 1)
	var corr := []
	for lag in lags:
		var acc := 0.0
		for i in x.size() - lag:
			acc += x[i] * x[i + lag]
		corr.append(acc / (x.size() - lag))
	var top: float = corr.max()
	for k in corr.size():
		if corr[k] >= top * 0.9 and (k == 0 or corr[k] >= corr[k - 1]) and (k == corr.size() - 1 or corr[k] >= corr[k + 1]):
			return RATE / lags[k]
	return 0.0


func _rms(buf: PackedVector2Array) -> float:
	var acc := 0.0
	for s in buf:
		acc += s.x * s.x
	return sqrt(acc / buf.size())


func test_pitch_is_the_v8_firing_frequency() -> void:
	for rpm in [8000.0, 16000.0]:
		var hz := _firing_hz(_render(rpm, 1.0), 300.0, 1500.0)
		print("  %d rpm -> %.0f Hz (firing %.0f Hz)" % [rpm, hz, rpm / 15.0])
		assert_near(hz, rpm / 15.0, rpm / 15.0 * 0.05, "%d rpm" % rpm)


func test_louder_on_the_throttle_and_bounded() -> void:
	var on := _render(15000.0, 1.0)
	var off := _render(15000.0, 0.0)
	assert_true(_rms(on) > _rms(off) * 1.4, "on %.3f off %.3f" % [_rms(on), _rms(off)])
	for s in on:
		assert_true(absf(s.x) <= 1.0 and absf(s.y) <= 1.0)
		if absf(s.x) > 1.0:
			break


func test_silent_at_zero_gain() -> void:
	assert_near(_rms(_render(15000.0, 1.0, 0.0)), 0.0, 1e-6)


func test_rivals_fade_with_distance() -> void:
	assert_true(EngineAudio.distance_gain(10.0) > EngineAudio.distance_gain(60.0) * 3.0)
	assert_eq(EngineAudio.distance_gain(EngineAudio.HEARING_RANGE + 1.0), 0.0)


func test_doppler_raises_an_approaching_car() -> void:
	var listener := Vector2.ZERO
	var other := Vector2(50.0, 0.0)
	var approaching := EngineAudio.doppler(listener, Vector2.ZERO, other, Vector2(-80.0, 0.0))
	var leaving := EngineAudio.doppler(listener, Vector2.ZERO, other, Vector2(80.0, 0.0))
	assert_true(approaching > 1.1 and leaving < 0.9, "%.2f / %.2f" % [approaching, leaving])


func test_rpm_of_a_car_without_engine_state_follows_its_speed() -> void:
	var spec := CarSpec.baseline_2012()
	var slow := EngineAudio.rpm_for_speed(spec, 20.0)
	var fast := EngineAudio.rpm_for_speed(spec, 85.0)
	assert_between(slow, Powertrain.DOWNSHIFT_TARGET_RPM * 0.6, Powertrain.UPSHIFT_RPM)
	assert_between(fast, Powertrain.DOWNSHIFT_TARGET_RPM * 0.6, Powertrain.UPSHIFT_RPM)


func test_baked_loop_closes_without_a_click() -> void:
	var wav := EngineAudio._bake_loop(1.0)
	var frames := wav.data.size() / 2
	assert_eq(wav.loop_end, frames)
	assert_eq(frames % int(EngineAudio.LOOP_RATE * 120.0 / EngineAudio.REF_RPM), 0, "whole engine cycles")
	var last := wav.data.decode_s16((frames - 1) * 2) / 32767.0
	var first := wav.data.decode_s16(0) / 32767.0
	var second := wav.data.decode_s16(2) / 32767.0
	assert_true(absf(first - last) < absf(second - first) * 4.0 + 0.05, "seam %.3f -> %.3f" % [last, first])
