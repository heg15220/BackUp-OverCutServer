extends TestCase
## Tyre heat and wear over real driving: a clean lap keeps the tyres in their window, a
## straight does not cook the driven wheels, wheelspin does heat them, and a medium lasts
## a realistic stint (Pirelli 2012: ~20-30 laps).

var model := SeasonModel.load_2012()
var track := TrackLoader.load_track("res://data/tracks/melbourne_2012.json")


## Drives `laps` flying laps with the Legend AI on the player's (uncompensated) car.
## Returns per-lap [mean front °C, mean rear °C, max °C, wear of the most-worn tyre, lap s].
func _drive(compound: StringName, laps: int) -> Array:
	var env := TrackEnvironment.on(track.data)
	var spec := model.car_spec("mclaren", "australia", false)
	var ai := AiDriver.new(track, SpeedProfile.build(track, spec, compound), AiSkill.level(AiSkill.LEGEND), 1)
	var s := CarState.create(spec, compound, 85.0)
	var slot := track.grid[0]
	s.position = slot.position
	s.heading = slot.heading
	s.track_index = slot.index
	var out := []
	var t := 0.0
	var lap_t := 0.0
	var sf := 0.0
	var sr := 0.0
	var n := 0
	var mx := 0.0
	while out.size() < laps and t < 150.0 * laps:
		var prev := s.track_index
		VehicleSim.step(s, spec, Assists.apply(ai.drive(s, SimClock.TICK), s, spec, ai.assists), env, SimClock.TICK)
		t += SimClock.TICK
		sf += (s.wheels[0].tyre.temp_c + s.wheels[1].tyre.temp_c) * 0.5
		sr += (s.wheels[2].tyre.temp_c + s.wheels[3].tyre.temp_c) * 0.5
		n += 1
		for w in s.wheels:
			mx = maxf(mx, w.tyre.temp_c)
		if prev > track.data.points.size() - 30 and s.track_index < 30 and t > 5.0:
			var wear := 0.0
			for w in s.wheels:
				wear = maxf(wear, w.tyre.wear)
			out.append([sf / n, sr / n, mx, wear, t - lap_t])
			lap_t = t
			sf = 0.0
			sr = 0.0
			n = 0
			mx = 0.0
	return out


func test_clean_laps_keep_the_tyres_in_their_window() -> void:
	var laps := _drive(&"medium", 3)
	assert_eq(laps.size(), 3, "three laps completed")
	for k in laps.size():
		var l: Array = laps[k]
		print("  lap %d: %.2f s  front %.0f °C  rear %.0f °C  max %.0f °C  wear %.3f" % [k, l[4], l[0], l[1], l[2], l[3]])
	var last: Array = laps[-1]
	# Medium window 95-120 °C: a clean lap runs in it, never far above it.
	assert_between(last[0], 92.0, 120.0, "front mean")
	assert_between(last[1], 95.0, 122.0, "rear mean")
	assert_true(last[2] < 140.0, "peak %.0f" % last[2])


func test_a_medium_lasts_a_real_stint() -> void:
	var laps := _drive(&"medium", 3)
	var per_lap: float = (laps[-1][3] - laps[0][3]) / (laps.size() - 1)
	print("  medium wear per lap %.4f -> %.0f laps to the cliff" % [per_lap, 0.75 / maxf(per_lap, 1e-6)])
	assert_between(per_lap, 0.022, 0.045, "wear per lap")


func test_full_throttle_on_a_straight_does_not_cook_the_rears() -> void:
	var spec := CarSpec.baseline_2012()
	var s := CarState.create(spec, &"medium", 100.0)
	s.velocity = Vector2(45.0, 0.0)
	var input := DriverInput.new()
	input.throttle = 1.0
	var env := TrackEnvironment.flat()
	for i in 120 * 8:
		VehicleSim.step(s, spec, Assists.apply(input, s, spec, AssistConfig.new()), env, SimClock.TICK)
	var rear := (s.wheels[2].tyre.temp_c + s.wheels[3].tyre.temp_c) * 0.5
	assert_true(rear < 112.0, "rear %.1f °C after 8 s flat out from 160 km/h" % rear)


func test_wheelspin_heats_the_rears_quickly() -> void:
	var spec := CarSpec.baseline_2012()
	var s := CarState.create(spec, &"medium", 80.0)
	s.velocity = Vector2(8.0, 0.0)
	var input := DriverInput.new()
	input.throttle = 1.0
	var env := TrackEnvironment.flat()
	for i in 120 * 2:
		VehicleSim.step(s, spec, input, env, SimClock.TICK)
	var rear := (s.wheels[2].tyre.temp_c + s.wheels[3].tyre.temp_c) * 0.5
	assert_true(rear > 92.0, "rear %.1f °C after 2 s of wheelspin" % rear)
