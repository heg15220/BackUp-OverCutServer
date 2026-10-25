extends TestCase


func _controls() -> TouchControls:
	var c := TouchControls.new()
	c.size = Vector2(1000, 500)
	return c


func _center(c: TouchControls, zone: int) -> Vector2:
	return c.zone_rect(zone).get_center()


func test_pedal_deadzone_and_progressive() -> void:
	var c := _controls()
	assert_near(c.pedal_value(0.05 * 200.0, 200.0), 0.946, 0.005)
	assert_near(c.pedal_value(0.5 * 200.0, 200.0), 0.457, 0.005)
	assert_near(c.pedal_value(200.0, 200.0), 0.0, 1e-6)
	assert_near(c.pedal_value(0.95 * 200.0, 200.0), 0.0, 1e-6, "inside the dead zone")
	c.free()


func test_steer_value_inner_to_outer() -> void:
	var c := _controls()
	assert_near(c.steer_value(0.0, 100.0, true), 0.35, 1e-6)
	assert_near(c.steer_value(100.0, 100.0, true), 1.0, 1e-6)
	assert_near(c.steer_value(100.0, 100.0, false), 0.35, 1e-6)
	assert_near(c.steer_value(0.0, 100.0, false), 1.0, 1e-6)
	c.free()


func test_multitouch_finger_keeps_its_control() -> void:
	var c := _controls()
	c.handle_touch(0, _center(c, TouchControls.Zone.THROTTLE), true)
	c.handle_touch(1, _center(c, TouchControls.Zone.STEER_LEFT), true)
	assert_true(c.throttle > 0.0)
	assert_true(c.steer < 0.0)
	c.handle_drag(0, _center(c, TouchControls.Zone.BRAKE))
	assert_true(c.throttle > 0.0, "finger 0 is still the throttle")
	assert_near(c.brake, 0.0, 1e-6)
	c.handle_touch(1, _center(c, TouchControls.Zone.STEER_LEFT), false)
	assert_near(c.steer, 0.0, 1e-6)
	c.handle_touch(0, Vector2.ZERO, false)
	assert_near(c.throttle, 0.0, 1e-6)
	c.free()


func test_touch_outside_zones_is_ignored() -> void:
	var c := _controls()
	c.handle_touch(0, Vector2(500, 20), true)
	assert_near(c.throttle + c.brake + absf(c.steer), 0.0, 1e-6)
	c.free()
