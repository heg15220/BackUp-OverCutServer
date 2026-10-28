extends TestCase
## The skidpad and straight-line envelopes are baked into data/speed_envelopes.json so a
## weekend loads in seconds. Stale tables would quietly change every AI's pace, so they are
## re-measured here; when the physics changes, re-bake with tools/bake_speed_envelopes.sh.


func _same(a: PackedFloat32Array, b: PackedFloat32Array) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		if not is_equal_approx(a[i], b[i]):
			return false
	return true


func test_baked_skidpad_matches_the_physics() -> void:
	var baked: Variant = SpeedProfile.baked_lateral(&"soft")
	assert_true(baked != null, "soft skidpad is baked")
	if baked != null:
		assert_true(_same(baked, SpeedProfile._skidpad(CarSpec.baseline_2012(), &"soft")), "stale: re-bake the envelopes")


func test_baked_envelope_matches_the_physics() -> void:
	var spec := SeasonModel.load_2012().car_spec("mclaren", "australia", true)
	var baked: Variant = SpeedProfile.baked_envelope(spec, &"soft")
	assert_true(baked != null, "McLaren at Albert Park is baked")
	if baked != null:
		var live := SpeedProfile.run_envelope(spec, &"soft")
		assert_true(_same(baked[0], live[0]) and _same(baked[1], live[1]), "stale: re-bake the envelopes")


func test_every_car_on_a_built_track_is_baked() -> void:
	var model := SeasonModel.load_2012()
	var missing := []
	for gp in model.data["calendar"]:
		if not App.TRACK_FILES.has(gp["circuit"]):
			continue
		for t in model.data["teams"]:
			for for_ai in [true, false]:
				if SpeedProfile.baked_envelope(model.car_spec(t["id"], gp["id"], for_ai), &"soft") == null:
					missing.append("%s %s ai=%s" % [gp["id"], t["id"], for_ai])
	assert_eq(missing.size(), 0, str(missing))


func test_same_car_is_measured_once() -> void:
	var spec := CarSpec.baseline_2012()
	spec.base_mu *= 1.0123  # not baked: measured live, then cached
	var t := Time.get_ticks_usec()
	var first := SpeedProfile.measure_envelope(spec, &"soft")
	var measured := Time.get_ticks_usec() - t
	t = Time.get_ticks_usec()
	var again := SpeedProfile.measure_envelope(spec.duplicate(), &"soft")
	var cached := Time.get_ticks_usec() - t
	assert_true(_same(first[0], again[0]) and _same(first[1], again[1]))
	assert_true(cached * 20 < measured, "cached %d us vs measured %d us" % [cached, measured])
