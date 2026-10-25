extends SceneTree
## 24 cars on the test circuit for 10 s of game time (1200 ticks).
## godot --headless --path <project> --script res://tests/bench/bench_sim.gd
## Target: mean <= 2.0 ms per tick on a desktop, leaving room for a ~3x slower phone.

const CARS := 24
const TICKS := 1200
const TARGET_MS := 2.0


func _initialize() -> void:
	var track := TestTrackBuilder.build()
	var env := TrackEnvironment.on(track)
	var spec := CarSpec.baseline_2012()
	var cars: Array[CarState] = []
	var n := track.points.size()
	for c in CARS:
		var i := (c * 7) % n
		var s := CarState.create(spec, &"medium", 95.0)
		s.position = track.points[i]
		s.heading = (track.points[(i + 1) % n] - track.points[i]).angle()
		cars.append(s)
	var input := DriverInput.new()
	var times := PackedFloat64Array()
	for t in TICKS:
		var t0 := Time.get_ticks_usec()
		for s in cars:
			var p := env.geometry.project_hinted(s.position + s.forward() * 15.0, s.track_index)
			input.throttle = 0.8
			input.steer = clampf(-p.lateral * 0.08 + angle_difference(s.heading, p.tangent.angle()) * 1.5, -1.0, 1.0)
			VehicleSim.step(s, spec, input, env, SimClock.TICK)
		times.append((Time.get_ticks_usec() - t0) / 1000.0)
	var sorted := times.duplicate()
	sorted.sort()
	var mean := 0.0
	for v in times:
		mean += v
	mean /= times.size()
	print("ms por tick (24 coches): media %.3f  p99 %.3f  objetivo <= %.1f  -> %s" % [mean, sorted[int(sorted.size() * 0.99)], TARGET_MS, "OK" if mean <= TARGET_MS else "LENTO"])
	quit(0 if mean <= TARGET_MS else 1)
