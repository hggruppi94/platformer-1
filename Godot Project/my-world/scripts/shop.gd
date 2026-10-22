extends Node

# Autoload "Shop": the market stalls. Walk up to a stall in the Market Square ("Press F to shop": scripts/shop_stall.gd)
# and a little shop opens with what that stall sells (res://shop/items.json), paid for in sparkles (scripts/game.gd).
#
# - Snacks are eaten straight away and fill HP (and MP).
# - Hats are kept and worn (one at a time); "Wear" and "Take off" swap them.
# - Stickers go on Rex's VOTE REX sash, so they need the sash first.
# What she owns is saved with her items ("shop:<id>"), the hat she's wearing as Game.hat. scripts/cosmetics.gd
# builds what they look like on her.

signal bought(item_id: String)

const DATA := "res://shop/items.json"

var items := {}                    # id -> item
var stall_blurbs := {}
var _stall := ""
var _layer: CanvasLayer
var _panel: PanelContainer
var _title: Label
var _blurb: Label
var _wallet: Label
var _rows: VBoxContainer
var _note: Label
var _close: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var data = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	if data is Dictionary:
		for it in data.get("items", []):
			items[str(it.id)] = it
		stall_blurbs = data.get("stalls", {})
	_build()
	Settings.changed.connect(_apply_look)
	_apply_look()


func for_stall(stall: String) -> Array:
	return items.values().filter(func(it: Dictionary) -> bool: return it.stall == stall)


func owns(id: String) -> bool:
	return Game.has_item("shop:" + id)


func can_buy(id: String) -> String:
	# "" if she can buy it now, else why not
	var it: Dictionary = items[id]
	if it.kind != "snack" and owns(id):
		return "You have this one"
	if it.kind == "sticker" and not Game.has_item("campaign_sash"):
		return "Needs Rex's VOTE REX sash"
	if Game.sparkles < int(it.price):
		return "Not enough sparkles yet"
	return ""


func buy(id: String) -> bool:
	if can_buy(id) != "":
		return false
	var it: Dictionary = items[id]
	Game.spend_sparkles(int(it.price))
	match str(it.kind):
		"snack":
			Game.hp = mini(Game.hp + int(it.get("hp", 0)), Game.max_hp)
			Game.mp = mini(Game.mp + int(it.get("mp", 0)), Game.max_mp)
			Game.stats_changed.emit()
			_say("Yum! %s. %s" % [it.name, it.text])
		"hat":
			Game.items.append("shop:" + id)
			Game.hat = id                                     # put it straight on
			_say("You got the %s! You're wearing it." % it.name)
		"sticker":
			Game.items.append("shop:" + id)
			_say("You stuck the %s on your sash!" % it.name)
	Audio.play("pickup", -4.0)
	Game.equipment_changed.emit()
	Game.save_game()
	bought.emit(id)
	_fill()
	return true


func wear(id: String) -> void:
	# Put a hat on (or "" to take it off)
	if id != "" and not owns(id):
		return
	Game.hat = id
	Game.equipment_changed.emit()
	Game.save_game()
	_fill()


# -----------------------------------------------------------------------------
# The shop window
# -----------------------------------------------------------------------------
func is_open() -> bool:
	return _layer.visible


func open(stall: String) -> void:
	if is_open() or get_tree().paused or Dialogue.is_active():
		return
	_stall = stall
	_note.text = ""
	_fill()
	_layer.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Audio.play("ui_accept", -4.0, 0.0)


func close() -> void:
	if not is_open():
		return
	_layer.visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Audio.play("ui_back", -4.0, 0.0)


func _unhandled_input(event: InputEvent) -> void:
	if is_open() and event.is_action_pressed("ui_cancel"):        # (Pause closes it too: scripts/pause_menu.gd)
		get_viewport().set_input_as_handled()
		close()
	elif is_open() and event.is_action_pressed("interact"):        # Interact presses the highlighted button
		var b := get_viewport().gui_get_focus_owner() as Button
		if b:
			get_viewport().set_input_as_handled()
			b.pressed.emit()


func _say(text: String) -> void:
	_note.text = text


func _fill() -> void:
	_title.text = "%s Stall" % _stall
	_blurb.text = str(stall_blurbs.get(_stall, ""))
	_wallet.text = "You have ✦ %d sparkle%s" % [Game.sparkles, "" if Game.sparkles == 1 else "s"]
	for c in _rows.get_children():
		c.queue_free()
	var first: Button = null
	for it in for_stall(_stall):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		var words := Label.new()
		words.text = "%s   ✦ %d\n%s" % [it.name, int(it.price), it.text]
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		words.add_theme_font_size_override("font_size", roundi(19 * Settings.text_scale))
		row.add_child(words)
		var b := Button.new()
		b.custom_minimum_size.x = roundi(170 * Settings.text_scale)
		b.add_theme_font_size_override("font_size", roundi(19 * Settings.text_scale))
		var id := str(it.id)
		if it.kind == "hat" and owns(id):
			b.text = "Take off" if Game.hat == id else "Wear"
			b.pressed.connect(wear.bind("" if Game.hat == id else id))
		else:
			var why := can_buy(id)
			b.text = ("Eat it!" if it.kind == "snack" else "Buy") if why == "" else ("Got it!" if why == "You have this one" else why)
			b.disabled = why != ""
			b.pressed.connect(buy.bind(id))
		b.name = "Button " + id
		row.add_child(b)
		_rows.add_child(row)
		if first == null and not b.disabled:
			first = b
	(first if first else _close).grab_focus.call_deferred()


func _build() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 33
	_layer.visible = false
	add_child(_layer)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(center)
	_panel = PanelContainer.new()
	center.add_child(_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	_panel.add_child(v)
	_title = Label.new()
	v.add_child(_title)
	_blurb = Label.new()
	v.add_child(_blurb)
	_wallet = Label.new()
	v.add_child(_wallet)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 10)
	v.add_child(_rows)
	_note = Label.new()
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_note)
	_close = Button.new()
	_close.text = "Bye!"
	_close.pressed.connect(close)
	v.add_child(_close)


func _apply_look() -> void:
	var hc := Settings.high_contrast
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.95) if hc else Color(0.12, 0.08, 0.18, 0.94)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(roundi(22 * Settings.text_scale))
	if hc:
		style.border_color = Color(1, 1, 1)
		style.set_border_width_all(2)
	_panel.add_theme_stylebox_override("panel", style)
	_panel.custom_minimum_size.x = roundi(640 * Settings.text_scale)
	_title.add_theme_font_size_override("font_size", roundi(30 * Settings.text_scale))
	_title.add_theme_color_override("font_color", Color(1, 0.9, 0.6))
	_blurb.add_theme_font_size_override("font_size", roundi(18 * Settings.text_scale))
	_wallet.add_theme_font_size_override("font_size", roundi(20 * Settings.text_scale))
	_wallet.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
	_note.add_theme_font_size_override("font_size", roundi(18 * Settings.text_scale))
	_note.add_theme_color_override("font_color", Color(0.75, 1.0, 0.8))
	_close.add_theme_font_size_override("font_size", roundi(19 * Settings.text_scale))
