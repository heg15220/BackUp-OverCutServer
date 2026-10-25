class_name DebugOverlay
extends Label
## Development telemetry: speed, gear, rpm, KERS, DRS and per-wheel tyre state.

const WHEEL_NAMES := ["DI", "DD", "TI", "TD"]

var controller: CarController
var extra := ""


func _ready() -> void:
	position = Vector2(12, 12)
	add_theme_font_size_override("font_size", 14)
	add_theme_color_override("font_color", Color(0.95, 0.97, 1.0))
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.06, 0.07, 0.10, 0.82)
	bg.set_content_margin_all(10)
	bg.set_corner_radius_all(6)
	add_theme_stylebox_override("normal", bg)


func _process(_delta: float) -> void:
	if controller == null:
		return
	var s := controller.state
	var pt := s.powertrain
	var lines := PackedStringArray()
	lines.append("%3d km/h   marcha %d   %5d rpm" % [roundi(Units.kmh(s.speed())), pt.gear, roundi(pt.rpm)])
	lines.append("KERS %3d%%   DRS %s   %s" % [roundi(100.0 * pt.kers_energy_j / (controller.spec.kers_energy_kj * 1000.0)), "ABIERTO" if s.drs_open else "cerrado", extra])
	for i in 4:
		var w := s.wheels[i]
		lines.append("%s %-12s %5.1f°C  desgaste %4.1f%%  %5d N  %-14s %s" % [
			WHEEL_NAMES[i], w.tyre.compound.id, w.tyre.temp_c, w.tyre.wear * 100.0, roundi(w.load_n),
			Surface.Type.keys()[w.surface], "DESLIZA" if w.sliding else ""])
	text = "\n".join(lines)
