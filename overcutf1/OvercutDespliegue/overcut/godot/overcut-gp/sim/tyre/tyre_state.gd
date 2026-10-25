class_name TyreState
extends RefCounted
## Thermal and wear state of one tyre, and the grip multiplier that follows from it.

## °C gained per second per watt of sliding power.
const HEAT_K := 0.00042
## Fraction of the gap to ambient lost per second (wet track multiplies it).
const COOL_K := 0.02
## Wear per joule of sliding energy for a wear_rate 1.0 compound (~25-30 laps of medium).
const WEAR_K := 7.0e-8
const TEMP_PENALTY_PER_DEG := 0.006
const MIN_TEMP_FACTOR := 0.6
const MIN_WEAR_FACTOR := 0.35
## Slicks: grip / (1 + SLICK_WATER_K * standing water above a damp film).
const SLICK_WATER_K := 4.0
## Wet-weather tyre on a drier track than it wants keeps at least this fraction.
const WET_TYRE_DRY_FLOOR := 0.88
const AQUAPLANE_FLOOR := 0.3

var compound: TyreCompound
var temp_c := 25.0
var wear := 0.0
var laps := 0


static func fresh(compound_id: StringName, temperature_c: float) -> TyreState:
	var t := TyreState.new()
	t.compound = TyreCompounds.get_compound(compound_id)
	t.temp_c = temperature_c
	return t


func grip_factor(water: float) -> float:
	return compound.grip * _temp_factor() * _wear_factor() * _water_factor(water)


func update(dt: float, slip_power_w: float, air_c: float, track_c: float, water: float) -> void:
	var overheated := temp_c > compound.temp_max
	var ambient := lerpf(track_c, air_c, 0.5)
	temp_c += (slip_power_w * HEAT_K - (temp_c - ambient) * COOL_K * (1.0 + 6.0 * water)) * dt
	wear = minf(1.0, wear + slip_power_w * WEAR_K * compound.wear_rate * (2.0 if overheated else 1.0) * dt)


func _temp_factor() -> float:
	var outside := 0.0
	if temp_c < compound.temp_min:
		outside = compound.temp_min - temp_c
	elif temp_c > compound.temp_max:
		outside = temp_c - compound.temp_max
	return maxf(MIN_TEMP_FACTOR, 1.0 - TEMP_PENALTY_PER_DEG * outside)


func _wear_factor() -> float:
	var f := 1.0 - 0.06 * wear
	if wear > compound.cliff_wear:
		f -= 1.2 * (wear - compound.cliff_wear)
	return maxf(MIN_WEAR_FACTOR, f)


func _water_factor(water: float) -> float:
	if not compound.is_wet_tyre:
		return 1.0 / (1.0 + SLICK_WATER_K * maxf(0.0, water - 0.05))
	var d := (water - compound.water_optimum) / compound.water_window
	var bell := exp(-d * d)
	if water <= compound.water_optimum:
		return WET_TYRE_DRY_FLOOR + (1.0 - WET_TYRE_DRY_FLOOR) * bell
	return maxf(AQUAPLANE_FLOOR, bell)
