extends SceneTree
## Runs one AI car alone for N laps on Albert Park: lap times and incidents.
## godot --headless --path . --script res://tests/bench/ai_laps.gd -- [--level=4] [--laps=3]
func _initialize() -> void:
	var level := AiSkill.LEGEND
	var laps := 3
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--level="): level = int(a.trim_prefix("--level="))
		if a.begins_with("--laps="): laps = int(a.trim_prefix("--laps="))
	var track := TrackLoader.load_track("res://data/tracks/melbourne_2012.json")
	var spec := CarSpec.baseline_2012()
	var env := TrackEnvironment.on(track.data)
	var profile := SpeedProfile.build(track, spec, &"soft")
	var s := CarState.create(spec, &"soft", 95.0)
	s.position = track.grid[0].position
	s.heading = track.grid[0].heading
	var skill := AiSkill.level(level)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--pace="): skill.pace = float(a.trim_prefix("--pace="))
	var ai := AiDriver.new(track, profile, skill)
	for a in OS.get_cmdline_user_args():
		if a == "--no-tc": ai.assists.traction_control = false
		if a == "--no-abs": ai.assists.abs = false
	var t := 0.0
	var last := -1.0
	var prev := s.track_index
	var times: Array[float] = []
	var offtrack := 0
	var was_off := false
	var walls := 0
	var was_wall := false
	while t < 160.0 * laps and times.size() < laps and not ai.gave_up:
		var input := Assists.apply(ai.drive(s, SimClock.TICK), s, spec, ai.assists)
		VehicleSim.step(s, spec, input, env, SimClock.TICK)
		t += SimClock.TICK
		var off := Surface.is_off_track(s.wheels[0].surface) and Surface.is_off_track(s.wheels[3].surface)
		if off and not was_off:
			offtrack += 1
			print("  off track at index %d, t=%.1f, v=%.0f km/h" % [s.track_index, t, s.speed() * 3.6])
		was_off = off
		if s.wall_contact and not was_wall:
			walls += 1
			print("  wall at index %d, t=%.1f, v=%.0f km/h" % [s.track_index, t, s.speed() * 3.6])
		was_wall = s.wall_contact
		if prev > track.data.points.size() - 20 and s.track_index < 20:
			if last >= 0.0: times.append(t - last)
			last = t
		prev = s.track_index
	print("level %s: laps %s  offtrack %d  wall hits %d  gave_up %s  profile-lap %.2f" % [AiSkill.NAMES[level], str(times), offtrack, walls, ai.gave_up, _profile_lap(profile)])
	quit()

func _profile_lap(p: SpeedProfile) -> float:
	var t := 0.0
	for i in p.speeds.size(): t += p.ds[i] / maxf(p.speeds[i], 1.0)
	return t
