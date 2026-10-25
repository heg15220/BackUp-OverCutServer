class_name TyreCompound
extends Resource
## One tyre compound. grip multiplies the car's base friction; temperatures in °C;
## wear_rate is relative to the medium; water_* describe where a wet-weather tyre works best.

@export var id: StringName
@export var grip := 1.0
@export var temp_min := 95.0
@export var temp_max := 120.0
@export var wear_rate := 1.0
@export var cliff_wear := 0.75
@export var is_wet_tyre := false
@export var water_optimum := 0.0
@export var water_window := 0.12
