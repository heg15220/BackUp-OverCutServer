class_name TyreCompounds
## Pirelli 2012 compound set (four dry compounds, intermediate and full wet).

const DRY_2012 := [&"supersoft", &"soft", &"medium", &"hard"]

# id: [grip, temp_min, temp_max, wear_rate, cliff_wear, is_wet, water_optimum, water_window]
const _TABLE := {
	&"supersoft": [1.035, 80.0, 105.0, 2.0, 0.70, false, 0.0, 0.12],
	&"soft": [1.020, 85.0, 110.0, 1.4, 0.72, false, 0.0, 0.12],
	&"medium": [1.000, 95.0, 120.0, 1.0, 0.75, false, 0.0, 0.12],
	&"hard": [0.985, 105.0, 130.0, 0.75, 0.78, false, 0.0, 0.12],
	&"intermediate": [0.93, 50.0, 85.0, 1.6, 0.75, true, 0.35, 0.30],
	&"wet": [0.89, 40.0, 75.0, 1.8, 0.75, true, 0.80, 0.45],
}

static var _cache := {}


static func get_compound(id: StringName) -> TyreCompound:
	if _cache.has(id):
		return _cache[id]
	var row: Array = _TABLE[id]
	var c := TyreCompound.new()
	c.id = id
	c.grip = row[0]
	c.temp_min = row[1]
	c.temp_max = row[2]
	c.wear_rate = row[3]
	c.cliff_wear = row[4]
	c.is_wet_tyre = row[5]
	c.water_optimum = row[6]
	c.water_window = row[7]
	_cache[id] = c
	return c
