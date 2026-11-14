extends Control

# Dash shows you round his gadget stall (Hayden, 13 Nov 2026 playtest: "there needs to be a tutorial for ... buying
# gadgets from dash's store. maybe after you complete a quest for him?"). His stall opens once you've caught his runaway
# Buzz Bot for him (quests/bike_boy.json, scripts/meetings.gd), and the first time you open it he walks you round the
# window: a speech bubble beside it (the window slides left to make room) points at each part in turn (your sparkles, a gadget and its blueprint, the buy
# button, refills, the help button, Bye). "Next" (Enter, Space, A or a click) goes on, Skip ends it, and closing the
# shop ends it too. The stall's "How does it work?" button (Shop._help) shows it again any time.
#
# Seen once, it's remembered as the Dialogue flag "tour_dash_shop" (saved with the game). It lives in the Shop's own
# CanvasLayer, so it sits over the window, and like the shop it runs while the game's paused.
# The same look as the player menu's tour (scripts/menu_tour.gd).

signal finished

const FLAG := "tour_dash_shop"
# [what it points at, what Dash says]. "row:<item>" / "button:<item>" are a row of the list and its button (the first
# of the ids that's showing), "wallet", "title", "help" and "close" are parts of the window.
const STEPS := [
	["title", "My gadget stall! Here's how it works."],
	["wallet", "Your sparkles. Spend them here!"],
	["row:star_popper", "Bring me a blueprint. I'll build it!"],
	["button:star_popper", "Press Get it! to buy."],
	["row:popper_refill,star_popper", "Gadgets need ammo. Pop enemies for more!"],
	["help", "Forgot? Press How does it work?"],
	["close", "Press Bye! when you're done. Have fun!"],
]

var shop: Node                              # the Shop autoload
var index := -1
var _bubble: PanelContainer
var _text: Label
var _count: Label
var _next: Button
var _skip: Button
var _arrow: Control
var _pulse := 0.0
var _lit: Control                           # what's glowing


func _init(the_shop: Node) -> void:
	shop = the_shop
	name = "ShopTour"
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_build()


func is_on() -> bool:
	return visible and index >= 0


func start() -> void:
	index = -1
	visible = true
	go(0)


func go(i: int) -> void:
	if i < 0:
		return
	if i >= STEPS.size():
		stop(true)
		return
	index = i
	_text.text = str(STEPS[i][1])
	_count.text = "%d / %d" % [i + 1, STEPS.size()]
	_next.text = "Done!" if i == STEPS.size() - 1 else "Next"
	_skip.visible = i < STEPS.size() - 1
	_unlight()
	var t := target()
	var sc := shop.get("_scroll") as ScrollContainer
	if t and sc and sc.is_ancestor_of(t):
		sc.ensure_control_visible.call_deferred(t)
	_place.call_deferred()
	_focus_next.call_deferred()


func step(by: int) -> void:
	go(clampi(index + by, 0, STEPS.size()))


func stop(seen := true) -> void:
	if index < 0 and not visible:
		return
	if seen:
		Dialogue.set_flag(FLAG)
	index = -1
	visible = false
	_unlight()
	_unshift()
	finished.emit()


func _focus_next() -> void:
	if is_on():
		_next.grab_focus()


# ----------------------------------------------------------------------------- what it points at
func target() -> Control:
	if index < 0:
		return null
	var what := str(STEPS[index][0])
	match what:
		"title":
			return shop.get("_title")
		"wallet":
			return shop.get("_wallet")
		"help":
			return shop.get("_help")
		"close":
			return shop.get("_close")
	var rows := shop.get("_rows") as Control
	var kind := what.get_slice(":", 0)
	for id in what.get_slice(":", 1).split(","):
		var row := rows.get_node_or_null("Row " + id) as Control if rows else null
		if row and row.visible:
			return row.get_node_or_null("Button " + id) as Control if kind == "button" else row
	return shop.get("_panel")


func _place() -> void:
	# To the right of the window, level with what it's talking about. If there isn't room, the window slides left to
	# make some (the shop's CenterContainer centres it in less of the screen while the tour's on). On a screen too
	# small for both side by side, the bubble sits over the bottom (or top) of the window instead.
	var t := target()
	if t == null or not is_on():
		return
	var to_me := get_global_transform().affine_inverse()
	var panel_node := shop.get("_panel") as Control
	var vp := size
	var gap := float(_fs(34))
	_text.custom_minimum_size.x = _fs(340)
	_bubble.reset_size()
	var w := _bubble.size.x
	var h := _bubble.size.y
	var need := w + gap + 16.0
	var panel: Rect2 = to_me * panel_node.get_global_rect()
	var centre := panel_node.get_parent() as Control
	var room := vp.x - panel.size.x >= need + 16.0
	if centre:
		var shift := -need if room and vp.x - panel.size.x < need * 2.0 else 0.0
		if not is_equal_approx(centre.offset_right, shift):
			centre.offset_right = shift
			return                           # (placed next frame, once the window's moved)
	panel = to_me * panel_node.get_global_rect()
	var r: Rect2 = to_me * t.get_global_rect()
	var y := clampf(r.get_center().y - h / 2.0, 16.0, vp.y - h - 16.0)
	if room and panel.end.x + gap + w <= vp.x - 8.0:
		_arrow.visible = true
		_bubble.position = Vector2(panel.end.x + gap, y)
		_arrow.size = Vector2(_fs(28), _fs(34))
		_arrow.position = Vector2(panel.end.x + gap - _arrow.size.x + 2.0, r.get_center().y - _arrow.size.y / 2.0)
	else:
		_arrow.visible = false
		_bubble.position = Vector2(clampf(r.get_center().x - w / 2.0, 16.0, vp.x - w - 16.0),
			vp.y - h - 16.0 if r.get_center().y < vp.y / 2.0 else 16.0)
	_arrow.queue_redraw()


func _unshift() -> void:
	var centre := (shop.get("_panel") as Control).get_parent() as Control
	if centre:
		centre.offset_right = 0.0


func _process(delta: float) -> void:
	if not is_on():
		return
	if not shop.call("is_open"):
		stop(true)                       # (closing the shop ends it; the help button shows it again)
		return
	_place()
	# What it's talking about glows gently
	_pulse += delta
	var t := target()
	if t != _lit:
		_unlight()
		_lit = t
	if _lit and _lit != shop.get("_panel"):
		var glow := 1.0 + 0.3 * (0.5 + 0.5 * sin(_pulse * 5.0))
		_lit.modulate = Color(glow, glow, glow * 0.8) if not Settings.reduce_flashing else Color(1.15, 1.15, 0.95)


func _unlight() -> void:
	if _lit and is_instance_valid(_lit):
		_lit.modulate = Color.WHITE
	_lit = null


# ----------------------------------------------------------------------------- look
func _fs(px: float) -> int:
	return roundi(px * Settings.text_scale)


func _build() -> void:
	_arrow = Control.new()
	_arrow.name = "Arrow"
	_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arrow.draw.connect(func() -> void:
		var s := _arrow.size
		var pts := PackedVector2Array([Vector2(0, s.y / 2.0), Vector2(s.x, 0), Vector2(s.x, s.y)])
		_arrow.draw_colored_polygon(pts, UiStyle.GOLD)
		_arrow.draw_polyline(PackedVector2Array([pts[1], pts[0], pts[2]]), UiStyle.INK, 3.0, true))
	add_child(_arrow)
	_bubble = PanelContainer.new()
	_bubble.name = "Bubble"
	add_child(_bubble)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_bubble.add_child(v)
	var who := Label.new()
	who.name = "Who"
	who.text = "Dash"
	v.add_child(who)
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
	theme = UiStyle.theme()
	var card := UiStyle.card(Color(0, 0, 0, 0.97) if Settings.high_contrast else Color(0.24, 0.15, 0.4, 0.98),
		Settings.high_contrast, Settings.text_scale)
	card.border_color = Color(1, 1, 0.6) if Settings.high_contrast else UiStyle.GOLD
	card.set_border_width_all(3)
	card.set_content_margin_all(_fs(16))
	_bubble.add_theme_stylebox_override("panel", card)
	var who := _bubble.find_child("Who", true, false) as Label
	who.add_theme_font_size_override("font_size", _fs(18))
	who.add_theme_color_override("font_color", UiStyle.TEAL)
	_text.custom_minimum_size.x = _fs(380)
	_text.add_theme_font_size_override("font_size", _fs(22))
	_count.add_theme_font_size_override("font_size", _fs(16))
	_count.modulate = Color(1, 1, 1, 0.7)
	for b in [_next, _skip]:
		b.custom_minimum_size = Vector2(_fs(100), _fs(44))
