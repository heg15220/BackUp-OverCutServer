extends TestCase

var spec := CarSpec.baseline_2012()


func test_peak_power_about_560kw() -> void:
	var pt := Powertrain.new(spec)
	var peak := 0.0
	for rpm in range(4000, 18001, 50):
		peak = maxf(peak, pt.engine_torque(rpm, 1.0) * rpm * TAU / 60.0)
	assert_between(peak / 1000.0, 540.0, 580.0)


func test_limiter_cuts_torque() -> void:
	assert_near(Powertrain.new(spec).engine_torque(18100, 1.0), 0.0, 1e-6)


func test_kers_lasts_about_6_7s() -> void:
	var pt := Powertrain.new(spec)
	pt.gear = 6
	pt.update_rpm(70.0)
	var dt := 1.0 / 120.0
	var t := 0.0
	while pt.kers_energy_j > 0.0 and t < 20.0:
		pt.drive_force(1.0, true, dt)
		t += dt
	assert_between(t, 6.5, 6.9)
	assert_near(pt.drive_force(1.0, true, dt), pt.drive_force(1.0, false, dt), 1e-3, "no KERS once empty")
	pt.reset_kers_lap()
	assert_true(pt.drive_force(1.0, true, dt) > pt.drive_force(1.0, false, dt))


func test_auto_shift_up_near_limiter() -> void:
	var pt := Powertrain.new(spec)
	pt.gear = 3
	pt.update_rpm(pt.speed_at(17900.0, 3))
	pt.auto_shift()
	assert_eq(pt.gear, 4)


func test_auto_shift_down_when_slow() -> void:
	var pt := Powertrain.new(spec)
	pt.gear = 5
	pt.update_rpm(pt.speed_at(9000.0, 5))
	pt.auto_shift()
	assert_eq(pt.gear, 4)


func test_top_gear_speed_at_limiter() -> void:
	# 7th is geared so the limiter sits above the DRS-open top speed.
	assert_between(Units.kmh(Powertrain.new(spec).speed_at(18000.0, 7)), 325.0, 345.0)
