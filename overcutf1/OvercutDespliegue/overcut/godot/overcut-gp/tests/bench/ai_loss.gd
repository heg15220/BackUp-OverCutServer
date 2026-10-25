extends SceneTree
## Where does the AI lose time against its own target (profile x pace)? Per 50-point bucket.
var _last_printed := -1


func _initialize() -> void:
	var track := TrackLoader.load_track("res://data/tracks/melbourne_2012.json")
	var spec := CarSpec.baseline_2012()
	var env := TrackEnvironment.on(track.data)
	var profile := SpeedProfile.build(track, spec, &"soft")
	var skill := AiSkill.level(AiSkill.LEGEND)
	skill.pace = 0.95
	var s := CarState.create(spec, &"soft", 95.0)
	s.position = track.grid[0].position
	s.heading = track.grid[0].heading
	var ai := AiDriver.new(track, profile, skill)
	var n := track.data.points.size()
	var actual := PackedFloat32Array(); actual.resize(22)
	var ideal := PackedFloat32Array(); ideal.resize(22)
	var t := 0.0
	var laps := 0
	var prev := s.track_index
	while t < 400.0 and laps < 2:
		var raw := ai.drive(s, SimClock.TICK)
		ai.last_input = Assists.apply(raw, s, spec, ai.assists)
		VehicleSim.step(s, spec, ai.last_input, env, SimClock.TICK)
		t += SimClock.TICK
		var i := s.track_index
		if false:
			_last_printed = i
			var rl := s.wheels[2]
			print("i=%d v=%.1f target=%.1f thr=%.2f brk=%.2f st=%.2f lat=%.2f rlfy/av=%.2f" % [i, s.speed() * 3.6, profile.speeds[i] * skill.pace * 3.6, ai.last_input.throttle, ai.last_input.brake, ai.last_input.steer, env.geometry.project(s.position).lateral - track.racing_line[i], rl.fy / maxf(rl.avail_n, 1.0)])
		if laps == 1 and i >= 0:
			var b := i / 50
			actual[b] += SimClock.TICK
			ideal[b] += SimClock.TICK * s.speed() / maxf(profile.speeds[i] * skill.pace, 1.0)
		if prev > n - 20 and i < 20: laps += 1
		prev = i
	var lines := []
	var tot_a := 0.0
	var tot_i := 0.0
	for b in 22:
		tot_a += actual[b]; tot_i += ideal[b]
		lines.append("%d-%d: %.2fs (+%.2f)" % [b * 50, b * 50 + 49, actual[b], actual[b] - ideal[b]])
	print(" | ".join(lines))
	print("lap %.2f s, target %.2f s" % [tot_a, tot_i])
	quit()
