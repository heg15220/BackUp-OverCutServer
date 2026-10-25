class_name AssistConfig
extends Resource
## Which driver aids are on. The braking-line overlay is drawn by the HUD (plan 6).

@export var traction_control := false
@export var abs := false
@export var auto_gearbox := true
## Speed-sensitive steering for analog sticks too (digital and touch always get it).
@export var steer_assist := false
