extends SceneTree
## Legend AI lap time vs a grip/downforce compensation factor on the AI car.
func _initialize() -> void:
	var track := TrackLoader.load_track("res://data/tracks/melbourne_2012.json")
	for f in [1.12, 1.16, 1.20]:
		var spec := CarSpec.baseline_2012()
		spec.base_mu *= f
		spec.cl_a *= f
		var profile := SpeedProfile.build(track, spec, &"soft")
		var env := TrackEnvironment.on(track.data)
		var s := CarState.create(spec, &"soft", 95.0)
		s.position = track.grid[0].position
		s.heading = track.grid[0].heading
		var skill := AiSkill.level(AiSkill.LEGEND)
		skill.pace = 0.96
		var ai := AiDriver.new(track, profile, skill)
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
		var plap := 0.0
		for i in profile.speeds.size(): plap += profile.ds[i] / profile.speeds[i]
		print("factor %.2f: profile %.2f s, AI laps %s, incidents %d" % [f, plap, str(times), incidents])
	quit()
