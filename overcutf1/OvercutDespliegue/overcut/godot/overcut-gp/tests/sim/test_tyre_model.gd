extends TestCase


func test_lateral_peak_near_peak_slip_angle() -> void:
	var f_peak := TyreModel.lateral_force(TyreModel.PEAK_SLIP_ANGLE, 4000.0, 1.7)
	assert_true(f_peak > TyreModel.lateral_force(0.05, 4000.0, 1.7))
	assert_true(f_peak > TyreModel.lateral_force(0.20, 4000.0, 1.7))
	assert_near(f_peak, 1.7 * 4000.0, 1.7 * 4000.0 * 0.03)


func test_lateral_falloff_after_peak() -> void:
	var f_peak := TyreModel.lateral_force(TyreModel.PEAK_SLIP_ANGLE, 4000.0, 1.7)
	assert_between(TyreModel.lateral_force(0.25, 4000.0, 1.7) / f_peak, 0.70, 0.95)


func test_lateral_is_odd_and_zero_at_zero() -> void:
	assert_near(TyreModel.lateral_force(0.0, 4000.0, 1.7), 0.0, 1e-6)
	assert_near(TyreModel.lateral_force(-0.07, 4000.0, 1.7), -TyreModel.lateral_force(0.07, 4000.0, 1.7), 1e-6)


func test_load_sensitivity_reduces_mu_at_high_load() -> void:
	assert_true(TyreModel.effective_mu(1.7, 9000.0) < TyreModel.effective_mu(1.7, 3000.0))


func test_compounds_2012_order() -> void:
	var g := TyreCompounds.DRY_2012.map(func(id): return TyreCompounds.get_compound(id).grip)
	assert_true(g[0] > g[1] and g[1] > g[2] and g[2] > g[3])
	assert_true(TyreCompounds.get_compound(&"wet").is_wet_tyre)
