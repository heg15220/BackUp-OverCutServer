extends SceneTree
## Constant steer, speed held by throttle: does the car push (understeer) or spin (oversteer)?
func _initialize() -> void:
	var spec := CarSpec.baseline_2012()
	for target_kmh in [55.0, 65.0, 72.0, 78.0, 85.0, 95.0]:
		var v0: float = target_kmh / 3.6
		var s := SimRunner.rolling(spec, v0, &"soft", 95.0)
		s.tc_enabled = true
		var input := DriverInput.new()
		input.steer = 0.42  # ~R 27 m kinematic
		var spun := false
		var max_yaw := 0.0
		for k in 600:
			var err := v0 - s.speed()
			input.throttle = clampf(0.3 + err * 0.8, 0.0, 1.0)
			VehicleSim.step(s, spec, input, TrackEnvironment.flat(), SimClock.TICK)
			max_yaw = maxf(max_yaw, absf(s.yaw_rate))
			var beta := absf(angle_difference(s.heading, s.velocity.angle()))
			if beta > 0.5:
				spun = true
		var radius := s.speed() / maxf(absf(s.yaw_rate), 1e-3)
		print("target %3d km/h -> v %5.1f km/h  yaw %.2f  R %5.1f m  lat %.2f g  spun=%s" % [target_kmh, s.speed() * 3.6, s.yaw_rate, radius, s.speed() * absf(s.yaw_rate) / 9.81, spun])
	quit()
