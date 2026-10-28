class_name CarSpec
extends Resource
## Physical parameters of one car. baseline_2012() is a generic 2012 F1 car
## (V8 2.4 L, KERS, DRS); the season data plan derives each team's car from it.

@export var mass_kg := 642.0  ## car + driver, no fuel
@export var wheelbase := 3.40
@export var cg_to_front := 1.84
@export var track_front := 1.80
@export var track_rear := 1.70
@export var cg_height := 0.30
## Share of the lateral load transfer taken by the front axle (roll stiffness balance).
## F1 set-ups run stiffer at the front so the car understeers at the limit.
@export var roll_stiffness_front := 0.62
@export var yaw_inertia := 1100.0
@export var tyre_radius := 0.33
@export var max_steer := 0.30  ## rad at the wheel
@export var base_mu := 1.95
## The 325 mm rear tyres grip more than the 245 mm fronts; without this the heavier, more
## load-sensitive rear axle would make the car oversteer at the limit.
@export var rear_grip_factor := 1.15

@export var max_power_kw := 560.0
@export var power_rpm := 17500.0
@export var rev_limit := 18000.0
@export var idle_rpm := 4000.0
@export var gear_ratios := PackedFloat32Array([22.4, 17.4, 14.0, 11.6, 9.7, 8.1, 6.65])  ## overall; 7th tops out above the DRS top speed
@export var shift_time := 0.04
@export var drivetrain_eff := 0.92
@export var kers_power_kw := 60.0
@export var kers_energy_kj := 400.0

@export var cd_a := 1.05
@export var cl_a := 5.0
@export var aero_balance_front := 0.44
@export var drs_cd_a_delta := -0.11
@export var drs_cl_a_delta := -0.50

## Under 4-5 g braking ~62 % of the load is on the front axle (h = 0.30 m, L = 3.4 m);
## 66 % front keeps the rears below their limit so the car stays stable on the brakes.
@export var brake_bias_front := 0.66
## Sized so full pedal saturates the fronts only below ~200 km/h (peak ~5 g at 300).
@export var max_brake_force_n := 27000.0
@export var fuel_capacity_kg := 160.0


static func baseline_2012() -> CarSpec:
	return CarSpec.new()


func cg_to_rear() -> float:
	return wheelbase - cg_to_front


## Hash of every tuning value: two specs with the same fingerprint drive identically,
## so measurements of one (SpeedProfile's envelopes) are valid for the other.
func fingerprint() -> String:
	var parts := PackedStringArray()
	for p in get_property_list():
		if p["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE:
			parts.append("%s=%s" % [p["name"], var_to_str(get(p["name"]))])
	return "|".join(parts).md5_text()
