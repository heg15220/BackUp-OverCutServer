extends SceneTree
func _initialize() -> void:
	var track := TrackLoader.load_track("res://data/tracks/melbourne_2012.json")
	var spec := CarSpec.baseline_2012()
	var p := SpeedProfile.build(track, spec, &"soft")
	var t := 0.0
	for i in p.speeds.size():
		t += p.ds[i] / maxf(p.speeds[i], 1.0)
	var vmin := INF
	var imin := 0
	for i in p.speeds.size():
		if p.speeds[i] < vmin:
			vmin = p.speeds[i]
			imin = i
	print("profile lap %.2f s, min %.1f km/h at %d, curvature there %.4f (R %.1f m)" % [t, vmin * 3.6, imin, p.curvature[imin], 1.0 / p.curvature[imin]])
	quit()
