extends TestCase


func test_offtrack_low_grip() -> void:
	assert_true(Surface.grip(Surface.Type.GRASS, 0.0) < 0.5)
	assert_true(Surface.grip(Surface.Type.GRAVEL, 0.0) < 0.5)


func test_gravel_high_rolling() -> void:
	assert_true(Surface.rolling_resistance(Surface.Type.GRAVEL) >= 10.0 * Surface.rolling_resistance(Surface.Type.ASPHALT))


func test_wet_white_line_worse_than_dry_kerb() -> void:
	assert_true(Surface.grip(Surface.Type.WHITE_LINE, 1.0) < Surface.grip(Surface.Type.KERB_LOW, 0.0))


func test_interpolates_water() -> void:
	assert_near(Surface.grip(Surface.Type.WHITE_LINE, 0.5), 0.76, 0.01)


func test_off_track_flags() -> void:
	assert_true(Surface.is_off_track(Surface.Type.GRASS))
	assert_true(Surface.is_off_track(Surface.Type.GRAVEL))
	assert_true(Surface.is_off_track(Surface.Type.WALL))
	assert_true(not Surface.is_off_track(Surface.Type.KERB_HIGH))
	assert_true(not Surface.is_off_track(Surface.Type.ASPHALT))
