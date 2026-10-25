extends TestCase


func test_cold_tyre_has_less_grip() -> void:
	assert_true(TyreState.fresh(&"medium", 40.0).grip_factor(0.0) < TyreState.fresh(&"medium", 105.0).grip_factor(0.0) * 0.8)


func test_in_window_equals_compound_grip() -> void:
	assert_near(TyreState.fresh(&"soft", 95.0).grip_factor(0.0), 1.020, 1e-6)


func test_cliff_drops_grip() -> void:
	var t := TyreState.fresh(&"supersoft", 95.0)
	t.wear = 0.9
	assert_true(t.grip_factor(0.0) < 1.035 * 0.85)


func test_slicks_useless_in_heavy_water() -> void:
	var t := TyreState.fresh(&"medium", 105.0)
	assert_true(t.grip_factor(0.6) < t.grip_factor(0.0) * 0.5)


func test_inter_beats_slick_when_damp_and_loses_when_dry() -> void:
	var s := TyreState.fresh(&"soft", 95.0)
	var i := TyreState.fresh(&"intermediate", 70.0)
	assert_true(i.grip_factor(0.3) > s.grip_factor(0.3))
	assert_true(i.grip_factor(0.0) < s.grip_factor(0.0))


func test_wet_beats_inter_in_heavy_rain() -> void:
	assert_true(TyreState.fresh(&"wet", 60.0).grip_factor(0.8) > TyreState.fresh(&"intermediate", 70.0).grip_factor(0.8))


func test_sliding_heats_and_wears() -> void:
	var t := TyreState.fresh(&"medium", 60.0)
	for i in 600:
		t.update(1.0 / 120.0, 40000.0, 22.0, 30.0, 0.0)
	assert_true(t.temp_c > 80.0, "temp %f" % t.temp_c)
	assert_true(t.wear > 0.0)


func test_overheating_doubles_wear_rate() -> void:
	var a := TyreState.fresh(&"medium", 110.0)
	var b := TyreState.fresh(&"medium", 140.0)
	a.update(0.01, 30000.0, 22.0, 30.0, 0.0)
	b.update(0.01, 30000.0, 22.0, 30.0, 0.0)
	assert_near(b.wear / a.wear, 2.0, 0.05)
