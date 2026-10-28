extends SceneTree
## Bakes SpeedProfile's skidpad and every built track's car envelopes into
## data/speed_envelopes.json (run through tools/bake_speed_envelopes.sh).


func _init() -> void:
	var model := SeasonModel.load_2012()
	var out := {"lateral": {"soft": Array(SpeedProfile._skidpad(CarSpec.baseline_2012(), &"soft"))}, "envelope": {}}
	for gp in model.data["calendar"]:
		if not App.TRACK_FILES.has(gp["circuit"]):
			continue
		for t in model.data["teams"]:
			for for_ai in [true, false]:
				var spec := model.car_spec(t["id"], gp["id"], for_ai)
				var env := SpeedProfile.run_envelope(spec, &"soft")
				out["envelope"]["%s|soft" % spec.fingerprint()] = [Array(env[0]), Array(env[1])]
		print("baked ", gp["id"])
	var f := FileAccess.open(SpeedProfile.BAKED_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(out, "", true, true))
	f.close()
	print("wrote %d envelopes to %s" % [out["envelope"].size(), SpeedProfile.BAKED_PATH])
	quit()
