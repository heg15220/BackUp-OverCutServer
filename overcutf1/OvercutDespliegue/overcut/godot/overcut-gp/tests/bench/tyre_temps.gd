extends SceneTree
## Tyre temperature and wear over laps driven by the Legend AI on the player's (plain) car
## and on an AI-compensated car, as the race uses them. Prints per lap: mean temps F/R, max
## temps, wear of the most-worn tyre, lap time.


func _initialize() -> void:
	var model := SeasonModel.load_2012()
	var track := TrackLoader.load_track("res://data/tracks/melbourne_2012.json")
	var env := TrackEnvironment.on(track.data)
	var geo := env.geometry
	for for_ai in [false, true]:
		for compound in [&"soft", &"medium"]:
			var spec := model.car_spec("mclaren", "australia", for_ai)
			var ai := AiDriver.new(track, SpeedProfile.build(track, spec, compound), AiSkill.level(AiSkill.LEGEND), 1)
			var s := CarState.create(spec, compound, 85.0)
			var slot := track.grid[0]
			s.position = slot.position
			s.heading = slot.heading
			s.track_index = slot.index
			var t := 0.0
			var lap_t := 0.0
			var laps := 0
			var sum_f := 0.0
			var sum_r := 0.0
			var n := 0
			var max_t := 0.0
			var out := "%s %s:" % ["AIcar" if for_ai else "player", compound]
			while laps < 4 and t < 600.0:
				var prev := s.track_index
				var input := Assists.apply(ai.drive(s, SimClock.TICK), s, spec, ai.assists)
				VehicleSim.step(s, spec, input, env, SimClock.TICK)
				t += SimClock.TICK
				sum_f += (s.wheels[0].tyre.temp_c + s.wheels[1].tyre.temp_c) * 0.5
				sum_r += (s.wheels[2].tyre.temp_c + s.wheels[3].tyre.temp_c) * 0.5
				n += 1
				for w in s.wheels:
					max_t = maxf(max_t, w.tyre.temp_c)
				if prev > track.data.points.size() - 30 and s.track_index < 30 and t > 5.0:
					var wear := 0.0
					for w in s.wheels:
						wear = maxf(wear, w.tyre.wear)
					out += " | L%d %.1fs F%d R%d max%d wear%.3f" % [laps, t - lap_t, roundi(sum_f / n), roundi(sum_r / n), roundi(max_t), wear]
					laps += 1
					lap_t = t
					sum_f = 0.0
					sum_r = 0.0
					n = 0
					max_t = 0.0
			print(out)
	quit()
