class_name UiKit
## Shared look for menus and HUD: dark broadcast style, red accent, touch-sized controls.

const BG := Color("#0e0f15")
const PANEL := Color("#191a24")
const PANEL_LIGHT := Color("#242633")
const ACCENT := Color("#e10600")
const TEXT := Color("#f2f4f8")
const MUTED := Color("#9aa3b5")
const GOOD := Color("#3ddc84")


static func theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 22
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", MUTED.darkened(0.3))
	t.set_stylebox("normal", "Button", _box(PANEL_LIGHT, 10, 2, PANEL_LIGHT.lightened(0.1)))
	t.set_stylebox("hover", "Button", _box(PANEL_LIGHT.lightened(0.08), 10, 2, ACCENT))
	t.set_stylebox("pressed", "Button", _box(ACCENT.darkened(0.2), 10, 2, ACCENT))
	t.set_stylebox("focus", "Button", _box(Color(0, 0, 0, 0), 10, 2, ACCENT))
	t.set_stylebox("disabled", "Button", _box(PANEL, 10, 1, PANEL))
	t.set_stylebox("panel", "PanelContainer", _box(PANEL, 14, 0, PANEL))
	t.set_constant("separation", "VBoxContainer", 12)
	t.set_constant("separation", "HBoxContainer", 12)
	return t


static func _box(color: Color, radius: int, border: int, border_color: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.set_border_width_all(border)
	s.border_color = border_color
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 12
	s.content_margin_bottom = 12
	return s


static func label(text: String, size := 22, color := TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func button(text: String, on_press: Callable, min_height := 64) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, min_height)
	b.pressed.connect(on_press)
	return b


## A full-screen page: dark background, a scrollable centred column with a title.
static func page(title: String, subtitle := "") -> Array:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var stripe := ColorRect.new()
	stripe.color = ACCENT
	stripe.set_anchors_preset(Control.PRESET_TOP_WIDE)
	stripe.custom_minimum_size = Vector2(0, 6)
	root.add_child(stripe)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_bottom", 28)
	scroll.add_child(margin)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(col)
	col.add_child(label(title, 40))
	if not subtitle.is_empty():
		col.add_child(label(subtitle, 20, MUTED))
	return [root, col]


## Columns that adapt to the screen: wide screens get several, phones in portrait one or two.
static func adaptive_grid(min_column_px := 300) -> GridContainer:
	var g := GridContainer.new()
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	g.add_theme_constant_override("h_separation", 14)
	g.add_theme_constant_override("v_separation", 14)
	var relayout := func():
		var w := g.size.x
		if w <= 0.0 and g.is_inside_tree():
			w = g.get_viewport_rect().size.x - 48
		g.columns = maxi(1, int((w + 14) / (min_column_px + 14)))
	g.ready.connect(relayout)
	g.resized.connect(relayout)
	g.child_entered_tree.connect(func(c: Node):
		if c is Control:
			c.size_flags_horizontal = Control.SIZE_EXPAND_FILL)
	return g


## UI reference size by orientation: landscape lays out on 1280x720, portrait on 720x1280,
## so text and buttons keep their physical size when a phone or tablet turns.
static func fit_window(win: Window) -> void:
	var s := win.size
	win.content_scale_size = Vector2i(720, 1280) if s.y > s.x else Vector2i(1280, 720)


static func color_chip(colors: Array, size := Vector2(56, 18)) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 0)
	for c in colors:
		var r := ColorRect.new()
		r.color = Color(c)
		r.custom_minimum_size = Vector2(size.x / colors.size(), size.y)
		h.add_child(r)
	return h


static func spacer(height: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, height)
	return c


## A large tappable card whose content is a column of controls (they ignore the pointer so
## the whole card is one button).
static func card_button(on_press: Callable, content: Array, min_height := 176) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, min_height)
	b.pressed.connect(on_press)
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 16)
	b.add_child(m)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 6)
	m.add_child(v)
	for c in content:
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(c)
	return b


## A boxed panel with a heading, for hub sections.
static func panel(title: String) -> Array:
	var pc := PanelContainer.new()
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	pc.add_child(v)
	v.add_child(label(title.to_upper(), 17, ACCENT))
	return [pc, v]


## One standings/results line: position, colour bar, name, value.
static func table_row(pos: String, color: Color, name: String, value: String, highlight := false) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	var p := label(pos, 18, MUTED)
	p.custom_minimum_size = Vector2(34, 0)
	p.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	p.autowrap_mode = TextServer.AUTOWRAP_OFF
	h.add_child(p)
	var bar := ColorRect.new()
	bar.color = color
	bar.custom_minimum_size = Vector2(5, 24)
	h.add_child(bar)
	var n := label(name, 18, Color("#ffd400") if highlight else TEXT)
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	n.autowrap_mode = TextServer.AUTOWRAP_OFF
	n.clip_text = true
	h.add_child(n)
	var v := label(value, 18)
	v.autowrap_mode = TextServer.AUTOWRAP_OFF
	h.add_child(v)
	return h
