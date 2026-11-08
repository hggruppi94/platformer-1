class_name MenuTour
extends Control

# A guided look round the player menu (scripts/player_menu.gd), for young players (Hayden's 7 Nov 2026 playtest asked
# for "a tutorial that walks you through the menus"). A speech bubble points at each picture tab in turn and says
# what's on that page in a sentence, while the page itself opens underneath. "Next" (Enter, Space, A or a click) goes
# on, Q / E (LB / RB) go back and on too, and closing the menu ends it.
#
# It starts by itself the first time the menu opens on a new game (with Settings > How-to tips on), and the pause
# menu's "Show me the menu" and the Skate sheet's tips button start it again. Seen once, it's remembered as the
# Dialogue flag "tour_menu" (saved with the game).

signal finished

const FLAG := "tour_menu"

var menu: Node                              # the player menu
var steps: Array = []                       # [sheet, text], in order
var index := -1
var _bubble: PanelContainer
var _text: Label
var _count: Label
var _next: Button
var _skip: Button
var _arrow: Control
var _pulse := 0.0


func _init(player_menu: Node) -> void:
	menu = player_menu
	name = "MenuTour"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_build()


func is_on() -> bool:
	return visible and index >= 0


func start(sheet_steps: Array) -> void:
	steps = sheet_steps
	index = -1
	visible = true
	go(0)


func go(i: int) -> void:
	if i < 0:
		return
	if i >= steps.size():
		stop(true)
		return
	index = i
	var sheet: String = steps[i][0]
	if menu.sheet != sheet:
		menu.call("show_sheet", sheet)
	_text.text = Settings.fill(str(steps[i][1]))
	_count.text = "%d / %d" % [i + 1, steps.size()]
	_next.text = "Done!" if i == steps.size() - 1 else "Next"
	_skip.visible = i < steps.size() - 1
	_place.call_deferred()
	_focus_next.call_deferred()


func step(by: int) -> void:
	go(clampi(index + by, 0, steps.size()))


func stop(seen := true) -> void:
	if index < 0 and not visible:
		return
	if seen:
		Dialogue.set_flag(FLAG)
	index = -1
	visible = false
	for b in (menu.get("_tab_buttons") as Dictionary).values():
		(b as Control).modulate = Color.WHITE
	finished.emit()


func _focus_next() -> void:
	if is_on():
		_next.grab_focus()


# ----------------------------------------------------------------------------- where the bubble goes
func _tab() -> Control:
	if index < 0:
		return null
	return (menu.get("_tab_buttons") as Dictionary).get(steps[index][0])


func _place() -> void:
	# Under its tab, pointing up at it, kept on the screen
	var tab := _tab()
	if tab == null or not is_on():
		return
	_bubble.reset_size()
	# In the tour's own units: the menu may be shrunk to fit the screen (UiStyle.fit_full_screen)
	var r := get_global_transform().affine_inverse() * tab.get_global_rect()
	var vp := size
	var w := _bubble.size.x
	var x := clampf(r.get_center().x - w / 2.0, 16.0, vp.x - w - 16.0)
	var y := r.end.y + _fs(26)
	_bubble.position = Vector2(x, y)
	_arrow.position = Vector2(r.get_center().x - _fs(16), r.end.y + _fs(4))
	_arrow.size = Vector2(_fs(32), _fs(24))
	_arrow.queue_redraw()


func _process(delta: float) -> void:
	if not is_on():
		return
	_place()
	# The tab it's talking about glows gently
	_pulse += delta
	var glow := 1.0 + 0.25 * (0.5 + 0.5 * sin(_pulse * 5.0))
	for which in (menu.get("_tab_buttons") as Dictionary):
		var b: Control = menu.get("_tab_buttons")[which]
		b.modulate = Color(glow, glow, glow * 0.8) if which == steps[index][0] and not Settings.reduce_flashing else Color.WHITE


# ----------------------------------------------------------------------------- look
func _fs(px: float) -> int:
	return roundi(px * Settings.text_scale)


func _build() -> void:
	_arrow = Control.new()
	_arrow.name = "Arrow"
	_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arrow.draw.connect(func() -> void:
		var s := _arrow.size
		_arrow.draw_colored_polygon(PackedVector2Array([Vector2(s.x / 2.0, 0), Vector2(s.x, s.y), Vector2(0, s.y)]), UiStyle.GOLD)
		_arrow.draw_polyline(PackedVector2Array([Vector2(0, s.y), Vector2(s.x / 2.0, 0), Vector2(s.x, s.y)]), UiStyle.INK, 3.0, true))
	add_child(_arrow)
	_bubble = PanelContainer.new()
	_bubble.name = "Bubble"
	add_child(_bubble)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_bubble.add_child(v)
	_text = Label.new()
	_text.name = "Text"
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_text)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	_count = Label.new()
	_count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_count)
	_skip = Button.new()
	_skip.name = "Skip"
	_skip.text = "Skip"
	_skip.pressed.connect(func():
		Audio.play("ui_back", -6.0, 0.0)
		stop(true))
	row.add_child(_skip)
	_next = Button.new()
	_next.name = "Next"
	_next.icon = UiIcons.get_icon("resume", 32)
	_next.pressed.connect(func():
		Audio.play("ui_accept", -6.0, 0.0)
		step(1))
	row.add_child(_next)
	apply_look()


func apply_look() -> void:
	var card := UiStyle.card(Color(0, 0, 0, 0.97) if Settings.high_contrast else Color(0.24, 0.15, 0.4, 0.98),
		Settings.high_contrast, Settings.text_scale)
	card.border_color = Color(1, 1, 0.6) if Settings.high_contrast else UiStyle.GOLD
	card.set_border_width_all(3)
	card.set_content_margin_all(_fs(16))
	_bubble.add_theme_stylebox_override("panel", card)
	_text.custom_minimum_size.x = _fs(420)
	_text.add_theme_font_size_override("font_size", _fs(24))
	_count.add_theme_font_size_override("font_size", _fs(16))
	_count.modulate = Color(1, 1, 1, 0.7)
	for b in [_next, _skip]:
		b.custom_minimum_size = Vector2(_fs(120), _fs(48))
