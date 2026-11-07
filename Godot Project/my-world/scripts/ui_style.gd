class_name UiStyle
extends RefCounted

# MyWorld's own look for every menu (plan item 15): one shared theme in the alien palette, lettered in the same comic
# hand (Kalam Bold, res://ui/fonts/Kalam-Bold.ttf, the subtitles' font: scripts/dialogue.gd) with the same thick dark
# outline. Rounded, chunky, kid-friendly buttons with a lip along the bottom that they sink into when pressed, a
# bright teal ring when focused (easy to follow on a controller), tabs that look like tabs (folder tabs on a panel),
# and cards for things like quests.
#
#   UiStyle.theme()                     # the theme, for Settings' text size and high contrast (menus set it on their root)
#   UiStyle.card(Color)                 # a card's StyleBox (quest cards, banners)
#   UiStyle.font()                      # the lettering
#
# ui/theme.tres is the same theme at the usual size, saved by tools/make_ui_theme.gd. It's the project's theme
# (project.godot, gui/theme/custom), so anything that doesn't set one of its own wears it too. Menus that follow
# Settings (scripts/pause_menu.gd, player_menu.gd, title_screen.gd, shop.gd...) set UiStyle.theme() on their root.
#
# Type variations on top of the usual controls:
#   "SheetTab" (Button): a folder tab, for rows of toggle buttons used as tabs (the player menu's sheets)
#   "SheetPanel" (PanelContainer): the page under a row of SheetTabs, joined to them
#   "Card" (PanelContainer): a card, lighter than a panel, with a gold edge
#   "Heading" (Label): big gold lettering

const FONT_PATH := "res://ui/fonts/Kalam-Bold.ttf"

# The alien palette (tools/theme.gd's oranges -> teal, reds -> magenta, greens -> lime, whites -> lavender)
const INK := Color(0.07, 0.03, 0.12)            # outlines and lips
const PANEL := Color(0.13, 0.08, 0.22, 0.96)
const PAGE := Color(0.19, 0.12, 0.32, 0.98)     # a sheet's page, and the open tab
const EDGE := Color(0.55, 0.4, 0.9)              # lavender borders
const BUTTON := Color(0.29, 0.18, 0.5)
const BUTTON_HOVER := Color(0.4, 0.26, 0.66)
const TEAL := Color(0.45, 1.0, 0.85)
const TEAL_DEEP := Color(0.2, 0.68, 0.58)
const GOLD := Color(1.0, 0.85, 0.35)
const MAGENTA := Color(1.0, 0.4, 0.75)
const TEXT := Color(0.97, 0.94, 1.0)

static var _font: Font


static func font() -> Font:
	if _font == null:
		_font = load(FONT_PATH) as Font             # (load, not preload: a preload broke the first headless import)
	return _font


static func theme(scale := -1.0, hc := false, use_settings := true) -> Theme:
	# The menus' theme. By default it follows Settings (text size, high contrast).
	if use_settings and Engine.get_main_loop() and (Engine.get_main_loop() as SceneTree).root.has_node("Settings"):
		var s := (Engine.get_main_loop() as SceneTree).root.get_node("Settings")
		scale = float(s.text_scale) if scale < 0.0 else scale
		hc = bool(s.high_contrast)
	if scale < 0.0:
		scale = 1.0
	var fs := func(px: float) -> int: return roundi(px * scale)
	var t := Theme.new()
	t.default_font = font()
	t.default_font_size = fs.call(22)

	# --- Panels ---
	var bg := box(Color(0, 0, 0, 0.97) if hc else PANEL, 18, Color(1, 1, 1) if hc else EDGE, 3)
	bg.shadow_color = Color(0, 0, 0, 0.35)
	bg.shadow_size = 0 if hc else 12
	bg.set_content_margin_all(fs.call(12))
	t.set_stylebox("panel", "PanelContainer", bg)
	t.set_stylebox("panel", "Panel", bg)

	# --- Buttons: chunky, with a lip they sink into ---
	var normal := _button_box(Color(0.1, 0.1, 0.1) if hc else BUTTON, Color(1, 1, 1) if hc else Color(0.47, 0.34, 0.8), scale)
	var hover := _button_box(Color(0.3, 0.3, 0.3) if hc else BUTTON_HOVER, Color(1, 1, 1) if hc else Color(0.65, 0.5, 1.0), scale)
	var on := _button_box(Color(1, 0.9, 0.1) if hc else TEAL_DEEP, Color(1, 1, 1) if hc else TEAL, scale)
	var down := _sunk(hover, scale)
	var on_down := _sunk(on, scale)
	var off := _button_box(Color(0.15, 0.13, 0.2, 0.7), Color(0.3, 0.27, 0.4), scale)
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.set_corner_radius_all(16)
	focus.border_color = Color(1, 0.9, 0.1) if hc else TEAL
	focus.set_border_width_all(4 if hc else 3)
	focus.set_expand_margin_all(3)
	for cls in ["Button", "OptionButton", "MenuButton", "CheckButton", "CheckBox"]:
		t.set_stylebox("normal", cls, normal)
		t.set_stylebox("hover", cls, hover)
		t.set_stylebox("pressed", cls, on if cls == "Button" else down)
		t.set_stylebox("hover_pressed", cls, on_down if cls == "Button" else down)
		t.set_stylebox("disabled", cls, off)
		t.set_stylebox("focus", cls, focus)
		t.set_color("font_color", cls, Color(1, 1, 1))
		t.set_color("font_hover_color", cls, Color(1, 1, 1))
		t.set_color("font_pressed_color", cls, Color(0, 0, 0) if hc else Color(1, 1, 1))
		t.set_color("font_hover_pressed_color", cls, Color(0, 0, 0) if hc else Color(1, 1, 1))
		t.set_color("font_focus_color", cls, Color(1, 0.9, 0.1) if hc else Color(0.75, 1.0, 0.93))
		t.set_color("font_disabled_color", cls, Color(1, 1, 1, 0.4))
		t.set_color("font_outline_color", cls, INK)
		t.set_constant("outline_size", cls, fs.call(6))
		t.set_constant("h_separation", cls, fs.call(8))
	# Check boxes and toggles sit flat in a list (their tick does the talking)
	for cls in ["CheckBox", "CheckButton"]:
		var flat := StyleBoxEmpty.new()
		flat.set_content_margin_all(fs.call(4))
		t.set_stylebox("normal", cls, flat)
		t.set_stylebox("pressed", cls, flat)
		t.set_stylebox("hover", cls, flat)
		t.set_stylebox("hover_pressed", cls, flat)

	# --- Labels ---
	t.set_color("font_color", "Label", Color(1, 1, 1) if hc else TEXT)
	t.set_color("font_outline_color", "Label", Color(0, 0, 0) if hc else INK)
	t.set_constant("outline_size", "Label", fs.call(6) if hc else fs.call(3))
	t.set_color("default_color", "RichTextLabel", Color(1, 1, 1) if hc else TEXT)
	t.set_font("normal_font", "RichTextLabel", font())
	t.set_font("bold_font", "RichTextLabel", font())
	t.set_type_variation("Heading", "Label")
	t.set_color("font_color", "Heading", Color(1, 1, 0.6) if hc else GOLD)
	t.set_constant("outline_size", "Heading", fs.call(8))
	t.set_font_size("font_size", "Heading", fs.call(32))

	# --- Tabs: folder tabs on a page ---
	var tab_on := _tab_box(Color(0, 0, 0, 0.97) if hc else PAGE, Color(1, 0.9, 0.1) if hc else GOLD, scale, true)
	var tab_off := _tab_box(Color(0.15, 0.15, 0.15) if hc else Color(0.17, 0.1, 0.29, 0.95), Color(1, 1, 1, 0.6) if hc else Color(0.42, 0.3, 0.7), scale, false)
	var tab_hover := _tab_box(Color(0.3, 0.3, 0.3) if hc else Color(0.27, 0.17, 0.45, 0.98), Color(1, 1, 1) if hc else EDGE, scale, false)
	var tab_focus := focus.duplicate() as StyleBoxFlat
	tab_focus.corner_radius_bottom_left = 0
	tab_focus.corner_radius_bottom_right = 0
	var page := box(Color(0, 0, 0, 0.97) if hc else PAGE, 16, Color(1, 0.9, 0.1) if hc else Color(0.5, 0.38, 0.85), 2)
	page.set_content_margin_all(fs.call(14))
	for cls in ["TabContainer", "TabBar"]:
		t.set_stylebox("tab_selected", cls, tab_on)
		t.set_stylebox("tab_unselected", cls, tab_off)
		t.set_stylebox("tab_hovered", cls, tab_hover)
		t.set_stylebox("tab_focus", cls, tab_focus)
		t.set_stylebox("tab_disabled", cls, tab_off)
		t.set_color("font_selected_color", cls, Color(1, 1, 0.6) if hc else GOLD)
		t.set_color("font_unselected_color", cls, Color(1, 1, 1, 0.8))
		t.set_color("font_hovered_color", cls, Color(1, 1, 1))
		t.set_color("font_outline_color", cls, INK)
		t.set_constant("outline_size", cls, fs.call(6))
		t.set_font_size("font_size", cls, fs.call(22))
	t.set_stylebox("panel", "TabContainer", page)
	t.set_constant("side_margin", "TabContainer", fs.call(10))
	# The player menu's sheets: toggle Buttons dressed as the same folder tabs, over a SheetPanel page
	t.set_type_variation("SheetTab", "Button")
	t.set_stylebox("normal", "SheetTab", tab_off)
	t.set_stylebox("hover", "SheetTab", tab_hover)
	t.set_stylebox("pressed", "SheetTab", tab_on)
	t.set_stylebox("hover_pressed", "SheetTab", tab_on)
	t.set_stylebox("focus", "SheetTab", tab_focus)
	t.set_color("font_color", "SheetTab", Color(1, 1, 1, 0.85))
	t.set_color("font_pressed_color", "SheetTab", Color(1, 1, 0.6) if hc else GOLD)
	t.set_color("font_hover_pressed_color", "SheetTab", Color(1, 1, 0.6) if hc else GOLD)
	t.set_type_variation("SheetPanel", "PanelContainer")
	t.set_stylebox("panel", "SheetPanel", page)

	# --- Cards ---
	t.set_type_variation("Card", "PanelContainer")
	t.set_stylebox("panel", "Card", card(Color(0.25, 0.16, 0.42) if not hc else Color(0.05, 0.05, 0.05), hc, scale))

	# --- Sliders, scroll bars, text boxes, tooltips ---
	var grab := Color(1, 0.9, 0.1) if hc else TEAL
	t.set_icon("grabber", "HSlider", _dot(fs.call(20), grab))
	t.set_icon("grabber_highlight", "HSlider", _dot(fs.call(24), grab))
	var track := box(Color(0.5, 0.5, 0.5) if hc else Color(0.33, 0.23, 0.53), 6, INK, 2)
	track.content_margin_top = fs.call(5)
	track.content_margin_bottom = fs.call(5)
	t.set_stylebox("slider", "HSlider", track)
	var fill := box(Color(1, 0.9, 0.1) if hc else TEAL_DEEP, 6, INK, 0)
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	var bar := box(Color(1, 1, 1, 0.08), 8, Color(0, 0, 0, 0), 0)
	var thumb := box(Color(0.6, 0.48, 0.95, 0.85), 8, Color(0, 0, 0, 0), 0)
	var thumb_hi := box(TEAL, 8, Color(0, 0, 0, 0), 0)
	t.set_stylebox("scroll", "VScrollBar", bar)
	t.set_stylebox("grabber", "VScrollBar", thumb)
	t.set_stylebox("grabber_highlight", "VScrollBar", thumb_hi)
	t.set_stylebox("grabber_pressed", "VScrollBar", thumb_hi)
	var field := box(Color(0.08, 0.05, 0.14), 10, Color(0.47, 0.34, 0.8), 2)
	field.set_content_margin_all(fs.call(8))
	var field_focus := field.duplicate() as StyleBoxFlat
	field_focus.border_color = TEAL
	t.set_stylebox("normal", "LineEdit", field)
	t.set_stylebox("focus", "LineEdit", field_focus)
	t.set_stylebox("panel", "TooltipPanel", box(PANEL, 10, EDGE, 2))
	var line := StyleBoxLine.new()
	line.color = Color(0.5, 0.38, 0.85, 0.6)
	line.thickness = 2
	t.set_stylebox("separator", "HSeparator", line)
	var pb_back := box(Color(0.1, 0.06, 0.16), 8, INK, 2)
	var pb_fill := box(TEAL_DEEP, 8, INK, 0)
	t.set_stylebox("background", "ProgressBar", pb_back)
	t.set_stylebox("fill", "ProgressBar", pb_fill)
	return t


static func box(c: Color, radius: int, border: Color, width: int) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = c
	b.set_corner_radius_all(radius)
	b.border_color = border
	b.set_border_width_all(width)
	b.anti_aliasing = true
	return b


static func card(c: Color, hc := false, scale := 1.0) -> StyleBoxFlat:
	# A card: rounded, a soft shadow, a gold edge along the left like a bookmark
	var b := box(c, 16, Color(1, 1, 1) if hc else Color(0.55, 0.42, 0.9), 2)
	b.border_width_left = roundi(8 * scale)
	b.border_color = Color(1, 0.9, 0.1) if hc else GOLD
	b.shadow_color = Color(0, 0, 0, 0.3)
	b.shadow_size = 0 if hc else 6
	b.shadow_offset = Vector2(0, 3)
	b.content_margin_left = roundi(20 * scale)
	b.content_margin_right = roundi(16 * scale)
	b.content_margin_top = roundi(12 * scale)
	b.content_margin_bottom = roundi(12 * scale)
	return b


static func _button_box(c: Color, rim: Color, scale: float) -> StyleBoxFlat:
	var b := box(c, 16, rim, 2)
	b.border_width_bottom = roundi(6 * scale)       # the lip: a darker band along the bottom
	b.border_color = rim
	b.content_margin_left = roundi(16 * scale)
	b.content_margin_right = roundi(16 * scale)
	b.content_margin_top = roundi(6 * scale)
	b.content_margin_bottom = roundi(6 * scale)
	b.shadow_color = Color(0, 0, 0, 0.3)
	b.shadow_size = 3
	b.shadow_offset = Vector2(0, 2)
	return b


static func _sunk(from: StyleBoxFlat, scale: float) -> StyleBoxFlat:
	# Pressed in: the lip shrinks and the words drop by as much, as if the button went down
	var b := from.duplicate() as StyleBoxFlat
	var lip := b.border_width_bottom
	b.border_width_bottom = roundi(2 * scale)
	b.content_margin_top += lip - b.border_width_bottom
	b.shadow_size = 0
	return b


static func _tab_box(c: Color, top: Color, scale: float, selected: bool) -> StyleBoxFlat:
	var b := box(c, 14, top, 2)
	b.corner_radius_bottom_left = 0
	b.corner_radius_bottom_right = 0
	b.border_width_bottom = 0
	b.border_width_top = roundi((5 if selected else 2) * scale)
	b.content_margin_left = roundi(14 * scale)
	b.content_margin_right = roundi(14 * scale)
	b.content_margin_top = roundi((8 if selected else 6) * scale)
	b.content_margin_bottom = roundi((6 if selected else 4) * scale)
	if not selected:
		b.expand_margin_top = -roundi(3 * scale)     # unselected tabs sit a little lower, behind the open one
	return b


static func _dot(size: int, c: Color) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var r := size / 2.0
	for y in size:
		for x in size:
			var d := Vector2(x + 0.5 - r, y + 0.5 - r).length()
			var a := clampf(r - d, 0.0, 1.0)
			var edge := clampf(r - 2.5 - d, 0.0, 1.0)              # a dark rim round the dot
			img.set_pixel(x, y, Color(INK.lerp(c, edge), a))
	return ImageTexture.create_from_image(img)
