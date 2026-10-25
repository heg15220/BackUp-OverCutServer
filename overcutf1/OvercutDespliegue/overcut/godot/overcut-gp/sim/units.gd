class_name Units
## Physical constants and unit conversions. The simulation runs in SI units;
## km/h only appears in UI and tests.

const G := 9.81
const AIR_DENSITY := 1.225


static func kmh(ms_value: float) -> float:
	return ms_value * 3.6


static func ms(kmh_value: float) -> float:
	return kmh_value / 3.6
