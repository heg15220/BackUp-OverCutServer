class_name App
extends Node
## Game entry point: the menus, the championship and the Grand Prix weekend.
## Menus live on a CanvasLayer; a weekend replaces them with the 3D scene and comes back
## with the race result.

const GP_NAMES := {
	"australia": "GP de Australia", "malaysia": "GP de Malasia", "china": "GP de China",
	"bahrain": "GP de Baréin", "spain": "GP de España", "monaco": "GP de Mónaco",
	"canada": "GP de Canadá", "europe": "GP de Europa", "great-britain": "GP de Gran Bretaña",
	"germany": "GP de Alemania", "hungary": "GP de Hungría", "belgium": "GP de Bélgica",
	"italy": "GP de Italia", "singapore": "GP de Singapur", "japan": "GP de Japón",
	"korea": "GP de Corea", "india": "GP de la India", "abu-dhabi": "GP de Abu Dabi",
	"united-states": "GP de Estados Unidos", "brazil": "GP de Brasil",
}
const CIRCUIT_NAMES := {
	"melbourne": "Albert Park, Melbourne", "sepang": "Sepang", "shanghai": "Shanghái",
	"bahrain": "Sakhir", "catalunya": "Montmeló", "monaco": "Montecarlo", "montreal": "Gilles Villeneuve",
	"valencia": "Valencia Street Circuit", "silverstone": "Silverstone", "hockenheimring": "Hockenheim",
	"hungaroring": "Hungaroring", "spa-francorchamps": "Spa-Francorchamps", "monza": "Monza",
	"marina-bay": "Marina Bay", "suzuka": "Suzuka", "yeongam": "Yeongam", "buddh": "Buddh",
	"yas-marina": "Yas Marina", "austin": "Circuito de las Américas", "interlagos": "Interlagos",
}
const TRACK_FILES := {"melbourne": "res://data/tracks/melbourne_2012.json"}

## Where the championship is saved (tests point it elsewhere).
var save_path := Championship.SAVE_PATH
var model: SeasonModel
var champ: Championship
## Choices made in the new-championship screens before the championship exists.
var draft := {}
var ui: CanvasLayer
var _ui_root: Control
var _weekend: Node


func _ready() -> void:
	InputMapper.ensure_actions()
	model = SeasonModel.load_2012()
	UiKit.fit_window(get_window())
	get_window().size_changed.connect(func():
		UiKit.fit_window(get_window())
		if is_instance_valid(_ui_root) and _ui_root.get_child_count() > 0 and _weekend == null:
			_rebuild_current())
	ui = CanvasLayer.new()
	ui.layer = 10
	add_child(ui)
	_ui_root = Control.new()
	_ui_root.theme = UiKit.theme()
	_ui_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(_ui_root)
	show_screen(func(): return TitleScreen.build(self))
	_dev_shortcuts()


## Dev flags (after `--`): --dev-weekend (straight into Melbourne with Hamilton),
## --dev-screen=team|driver|settings|hub|results, --capture=<png> for menu screenshots.
func _dev_shortcuts() -> void:
	var args := OS.get_cmdline_user_args()
	var screen := ""
	var capture := ""
	for a in args:
		if a.begins_with("--dev-screen="):
			screen = a.trim_prefix("--dev-screen=")
		elif a.begins_with("--capture="):
			capture = a.trim_prefix("--capture=")
	if "--dev-weekend" in args or screen != "":
		draft = {"team": "mclaren", "driver": "HAM", "level": AiSkill.LEGEND, "length": RaceRules.Length.LAPS_5, "camera": 1.0,
			"assists": {"traction_control": true, "abs": true, "auto_gearbox": true, "stability_control": false}}
		champ = Championship.create(model, "mclaren", "HAM", AiSkill.LEGEND, RaceRules.Length.LAPS_5)
	if "--dev-weekend" in args:
		play_round()
		return
	match screen:
		"team":
			show_screen(func(): return TeamScreen.build(self))
		"driver":
			show_screen(func(): return DriverScreen.build(self))
		"settings":
			show_screen(func(): return SettingsScreen.build(self, true))
		"hub", "results":
			var r := champ.simulate_order("australia", 1)
			_finish_round(champ.next_gp(), r["order"], r["fastest"], _rows_from_simulation(r))
			if screen == "hub":
				show_screen(func(): return HubScreen.build(self))
	if capture != "" and not "--dev-weekend" in args:
		await get_tree().create_timer(1.0).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(capture)
		get_tree().quit()


var _current_builder: Callable


## Rebuilds the screen on screen (the window turned between portrait and landscape).
func _rebuild_current() -> void:
	if _current_builder.is_valid():
		show_screen(_current_builder)


## Shows a screen; builder() -> Control is kept so the screen can be rebuilt on rotation.
func show_screen(builder: Callable) -> void:
	_current_builder = builder
	var screen: Control = builder.call()
	for c in _ui_root.get_children():
		c.queue_free()
	_ui_root.add_child(screen)
	ui.visible = true


func has_save() -> bool:
	return Championship.load_from(save_path, model) != null


func continue_championship() -> void:
	champ = Championship.load_from(save_path, model)
	if champ != null:
		show_screen(func(): return HubScreen.build(self))


func new_championship() -> void:
	draft = {"level": AiSkill.PROFESSIONAL, "length": RaceRules.Length.LAPS_5, "camera": 1.0,
		"assists": {"traction_control": true, "abs": true, "auto_gearbox": true, "stability_control": false}}
	show_screen(func(): return SeasonScreen.build(self))


func pick_team(team_id: String) -> void:
	draft["team"] = team_id
	show_screen(func(): return DriverScreen.build(self))


func pick_driver(code: String) -> void:
	draft["driver"] = code
	show_screen(func(): return SettingsScreen.build(self, true))


func start_championship() -> void:
	champ = Championship.create(model, draft["team"], draft["driver"], draft["level"], draft["length"])
	champ.assists = draft["assists"].duplicate()
	champ.camera_zoom = draft["camera"]
	champ.save(save_path)
	show_screen(func(): return HubScreen.build(self))


## Settings changed from the hub during a championship.
func apply_settings() -> void:
	champ.level = draft["level"]
	champ.length = draft["length"]
	champ.assists = draft["assists"].duplicate()
	champ.camera_zoom = draft["camera"]
	champ.save(save_path)
	show_screen(func(): return HubScreen.build(self))


func edit_settings() -> void:
	draft = {"team": champ.team_id, "driver": champ.player_code, "level": champ.level, "length": champ.length,
		"camera": champ.camera_zoom, "assists": champ.assists.duplicate()}
	show_screen(func(): return SettingsScreen.build(self, false))


func go_hub() -> void:
	show_screen(func(): return HubScreen.build(self))


func go_title() -> void:
	show_screen(func(): return TitleScreen.build(self))


## Runs the next round: the weekend scene for a built circuit, otherwise a simulated result.
func play_round() -> void:
	var gp := champ.next_gp()
	if champ.round_playable() and TRACK_FILES.has(gp["circuit"]):
		_start_weekend(gp)
	else:
		var r := champ.simulate_order(gp["id"], hash(gp["id"]) + champ.round * 7919)
		_finish_round(gp, r["order"], r["fastest"], _rows_from_simulation(r))


func _start_weekend(gp: Dictionary) -> void:
	for c in _ui_root.get_children():
		c.queue_free()
	# The menus' layer sits above the race HUD and its full-screen root stops the mouse.
	ui.visible = false
	var w := RaceWeekend.new()
	w.app = self
	w.gp = gp
	w.track_path = TRACK_FILES[gp["circuit"]]
	_weekend = w
	add_child(w)


## Called by the weekend when the race is over (rows: RaceWeekend.result_rows()).
func weekend_finished(order: Array, fastest: String, rows: Array) -> void:
	var gp := champ.next_gp()
	if is_instance_valid(_weekend):
		_weekend.queue_free()
	_weekend = null
	_finish_round(gp, order, fastest, rows)


## The player left the weekend before the end: nothing is scored, the round stays pending.
func weekend_abandoned() -> void:
	if is_instance_valid(_weekend):
		_weekend.queue_free()
	_weekend = null
	go_hub()


func _finish_round(gp: Dictionary, order: Array, fastest: String, rows: Array) -> void:
	var table: Array = model.data["points"]
	for k in rows.size():
		rows[k]["points"] = RaceRules.points_for(order.find(rows[k]["code"]) + 1, table) if rows[k]["code"] in order else 0
	champ.record_race(gp["id"], order, fastest)
	champ.save(save_path)
	show_screen(func(): return ResultsScreen.build(self, gp, rows, fastest))


func _rows_from_simulation(r: Dictionary) -> Array:
	var rows := []
	for code in r["order"]:
		rows.append({"code": code, "status": "", "gap": ""})
	for code in r["retired"]:
		rows.append({"code": code, "status": "Abandono", "gap": ""})
	return rows


func gp_name(gp: Dictionary) -> String:
	return GP_NAMES.get(gp["id"], gp["id"])


func circuit_name(gp: Dictionary) -> String:
	return CIRCUIT_NAMES.get(gp["circuit"], gp["circuit"])
