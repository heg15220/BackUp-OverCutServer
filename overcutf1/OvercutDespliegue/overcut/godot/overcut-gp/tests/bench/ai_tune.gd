extends SceneTree
## Grid search over the AI driving-style constants at a given pace: fastest clean 2-lap run.
func _initialize() -> void:
	var track := TrackLoader.load_track("res://data/tracks/melbourne_2012.json")
	var spec := CarSpec.baseline_2012()
	var profile := SpeedProfile.build(track, spec, &"soft")
	var pace := 0.96
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--pace="): pace = float(a.trim_prefix("--pace="))
	var results := []
	for look in [0.1, 0.2, 0.3]:
		for rel in [2.2]:
			for feed in [3.0]:  # here: brake gain
				var r := _run(track, spec, profile, pace, look, rel, feed)
				results.append(r)
				print("look %.2f rel %.1f feed %.2f -> %s" % [look, rel, feed, str(r)])
	quit()

func _run(track: LoadedTrack, spec: CarSpec, profile: SpeedProfile, pace: float, look: float, rel: float, feed: float) -> Array:
	var env := TrackEnvironment.on(track.data)
	var skill := AiSkill.level(AiSkill.LEGEND)
	skill.pace = pace
	var s := CarState.create(spec, &"soft", 95.0)
	s.position = track.grid[0].position
	s.heading = track.grid[0].heading
	var ai := AiDriver.new(track, profile, skill)
	ai.brake_lookahead_s = look
	ai.brake_release = rel
	ai.brake_gain = feed
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
	return [times, incidents]
