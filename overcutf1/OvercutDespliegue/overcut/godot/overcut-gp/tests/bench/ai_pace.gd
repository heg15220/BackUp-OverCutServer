extends SceneTree
## Legend AI on the plain car (no compensation): lap times and incidents at higher paces.
func _initialize() -> void:
	var track := TrackLoader.load_track("res://data/tracks/melbourne_2012.json")
	var spec := CarSpec.baseline_2012()
	var profile := SpeedProfile.build(track, spec, &"soft")
	var plap := 0.0
	for i in profile.speeds.size(): plap += profile.ds[i] / profile.speeds[i]
	print("profile %.2f s" % plap)
	for pace in [0.95, 0.97, 0.99, 1.0]:
		for seed in [1, 2]:
			var env := TrackEnvironment.on(track.data)
			var s := CarState.create(spec, &"soft", 95.0)
			s.position = track.grid[0].position
			s.heading = track.grid[0].heading
			var skill := AiSkill.level(AiSkill.LEGEND)
			skill.pace = pace
			var ai := AiDriver.new(track, profile, skill, seed)
			var t := 0.0
			var last := -1.0
			var prev := s.track_index
			var times := []
			var incidents := 0
			var was_bad := false
			while t < 400.0 and times.size() < 3 and not ai.gave_up:
				VehicleSim.step(s, spec, Assists.apply(ai.drive(s, SimClock.TICK), s, spec, ai.assists), env, SimClock.TICK)
				t += SimClock.TICK
				var bad := s.wall_contact or (Surface.is_off_track(s.wheels[0].surface) and Surface.is_off_track(s.wheels[3].surface))
				if bad and not was_bad: incidents += 1
				was_bad = bad
				if prev > track.data.points.size() - 20 and s.track_index < 20:
					if last >= 0.0: times.append(snappedf(t - last, 0.01))
					last = t
				prev = s.track_index
			print("pace %.2f seed %d: laps %s incidents %d gave_up %s" % [pace, seed, str(times), incidents, ai.gave_up])
	quit()
