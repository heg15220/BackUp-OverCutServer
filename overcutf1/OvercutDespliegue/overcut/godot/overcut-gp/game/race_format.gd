class_name RaceFormat
## Time and gap text as shown on timing screens.


## 86.312 -> "1:26.312"; INF -> "—".
static func lap_time(t: float) -> String:
	if t == INF or is_nan(t):
		return "—"
	var m := int(t / 60.0)
	return "%d:%06.3f" % [m, t - m * 60.0]


## Gap text: "+1.234", "+1 vuelta", "+3 vueltas".
static func gap(seconds: float, laps_down := 0) -> String:
	if laps_down > 0:
		return "+%d %s" % [laps_down, "vuelta" if laps_down == 1 else "vueltas"]
	return "+%.3f" % seconds


## Session clock: 305.2 -> "5:05".
static func clock(t: float) -> String:
	var s := maxi(0, ceili(t))
	return "%d:%02d" % [s / 60, s % 60]
