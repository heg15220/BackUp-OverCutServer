class_name TyreNames
## Pirelli 2012 compound names and sidewall colours for the HUD.

const NAMES := {&"supersoft": "Superblando", &"soft": "Blando", &"medium": "Medio", &"hard": "Duro", &"intermediate": "Intermedio", &"wet": "Lluvia"}
const SHORT := {&"supersoft": "SB", &"soft": "B", &"medium": "M", &"hard": "D", &"intermediate": "I", &"wet": "LL"}
const COLORS := {&"supersoft": Color("#e5322d"), &"soft": Color("#ffd400"), &"medium": Color("#f2f2f2"), &"hard": Color("#ff8a00"), &"intermediate": Color("#3ddc84"), &"wet": Color("#2f8fff")}


static func short(id: StringName) -> String:
	return NAMES.get(id, String(id))


static func color(id: StringName) -> Color:
	return COLORS.get(id, Color.WHITE)
