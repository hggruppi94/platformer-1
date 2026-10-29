extends Node

# Autoload "Shop": the market stalls. Walk up to a stall in the Market Square ("Press F to shop": scripts/shop_stall.gd)
# and a little shop opens with what that stall sells (res://shop/items.json), paid for in sparkles (scripts/game.gd).
#
# - Snacks are eaten straight away and fill HP (and MP).
# - Hats and clothes are kept and worn, one in each of her clothing slots (scripts/clothes.gd); "Wear" and "Take off"
#   swap them, and her wardrobe (the "Wardrobe" stall, in Nina's house and the Clothing Boutique) changes the lot.
# - Stickers go on Rex's VOTE REX sash, so they need the sash first.
# What she owns is saved with her items ("shop:<id>"), what she's wearing as Game.outfit. scripts/cosmetics.gd and
# scripts/clothes.gd build what they look like on her.
# - Other systems can sell their own kinds of thing here too: register_kind() hands a kind (say "gadget" or "ammo",
#   scripts/arsenal.gd) to whoever looks after it, and they say whether it can be bought and what buying it does. They
#   keep what was bought in their own save, so those items aren't added to Game.items.

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
var _keep_focus := ""              # the wardrobe button to stay on after the window refills
var who := "hero"                  # whose outfit and looks the wardrobe is changing (scripts/clothes.gd WHO)
var kinds := {}                    # kind -> {can_buy: Callable(item) -> String, buy: Callable(item) -> String, button}


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


func register_kind(kind: String, how: Dictionary) -> void:
	# Another system sells this kind of item here. `how` has "can_buy" (item -> "" or why not), "buy" (item -> what
	# to say after; it's already paid for) and, if it likes, "button" (what the Buy button says).
	kinds[kind] = how


func owns(id: String) -> bool:
	return Game.has_item("shop:" + id)


func can_buy(id: String) -> String:
	# "" if she can buy it now, else why not
	var it: Dictionary = items[id]
	if kinds.has(str(it.kind)):
		var why: String = kinds[str(it.kind)].can_buy.call(it)
		if why != "":
			return why
	elif it.kind != "snack" and owns(id):
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
	var wrapped_for := Requests.wrap(id) if str(it.kind) == "snack" else ""
	match str(it.kind):
		"snack" when wrapped_for != "":
			_say("Wrapped up with a bow for %s! (Now go and find them.)" % wrapped_for)    # a request board delivery
		"snack":
			Game.hp = mini(Game.hp + int(it.get("hp", 0)), Game.max_hp)
			Game.mp = mini(Game.mp + int(it.get("mp", 0)), Game.max_mp)
			Game.stats_changed.emit()
			_say("Yum! %s. %s" % [it.name, it.text])
		"hat", "clothes":
			Game.items.append("shop:" + id)
			Game.outfit[slot_of(id)] = id                     # put it straight on
			_say("You got the %s! You're wearing it." % it.name)
		"sticker":
			Game.items.append("shop:" + id)
			_say("You stuck the %s on your sash!" % it.name)
		var other when kinds.has(other):
			_say(str(kinds[other].buy.call(it)))
	Audio.play("pickup", -4.0)
	Game.equipment_changed.emit()
	Game.save_game()
	bought.emit(id)
	_fill()
	return true


func slot_of(id: String) -> String:
	return str(items[id].get("slot", "head")) if items.has(id) else "head"


func wearable(id: String) -> bool:
	return items.has(id) and str(items[id].kind) in ["hat", "clothes"]


func wear(id: String, slot := "head", on := "hero") -> void:
	# Put something on (or "" to take off whatever's in that slot), on Nina or a friend she's lending it to
	if id != "" and not owns(id):
		return
	if not Game.outfits.has(on):
		Game.outfits[on] = {}
	var outfit: Dictionary = Game.outfits[on]
	if id != "":
		slot = slot_of(id)
		outfit[slot] = id
	else:
		outfit.erase(slot)
	Game.equipment_changed.emit()
	Game.save_game()
	_fill()


func owned_for(slot: String) -> Array[String]:
	# Everything she owns that goes in this slot, in shop order
	var out: Array[String] = []
	for id in items:
		if wearable(id) and slot_of(id) == slot and owns(id):
			out.append(id)
	return out


func cycle(slot: String, step: int) -> void:
	# The wardrobe's arrows: the next thing she owns for this slot, with her own look ("") in the round too
	var choices: Array[String] = [""]
	choices.append_array(owned_for(slot))
	var i := choices.find(Game.outfits.get(who, {}).get(slot, ""))
	_keep_focus = "Button %s %d" % [slot, step]
	wear(choices[posmod(i + step, choices.size())], slot, who)


func cycle_look(part: String, step: int) -> void:
	# The wardrobe's colour arrows: the next colour for this part of their look (0 is how Sofi drew them)
	if not Game.looks.has(who):
		Game.looks[who] = {}
	var n: int = Clothes.PALETTE[part].size()
	Game.looks[who][part] = posmod(int(Game.looks[who].get(part, 0)) + step, n)
	_keep_focus = "Button look %s %d" % [part, step]
	Game.equipment_changed.emit()
	Game.save_game()
	_fill()


func cycle_who(step: int) -> void:
	who = Clothes.WHO[posmod(Clothes.WHO.find(who) + step, Clothes.WHO.size())]
	_keep_focus = "Button who %d" % step
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
	who = "hero"
	_apply_look()                      # the wardrobe's window is wider
	_note.text = ""
	_fill()
	_layer.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Audio.play("ui_accept", -4.0, 0.0)
	if not stall in ["Wardrobe", "Decorate"]:
		Tips.show_tip("shop")                      # the first time at a stall (scripts/tips.gd)


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
	if _stall == "Wardrobe":
		_fill_wardrobe()
		return
	if _stall == "Decorate":
		_fill_decorate()
		return
	_title.text = ("%s Stall" % _stall) if _stall != "Boutique" else "Clothing Boutique"
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
		if wearable(id) and owns(id):
			var on: bool = Game.outfit.get(slot_of(id), "") == id
			b.text = "Take off" if on else "Wear"
			b.pressed.connect(wear.bind("" if on else id, slot_of(id)))
		else:
			var why := can_buy(id)
			var label := "Eat it!" if it.kind == "snack" else str(kinds.get(str(it.kind), {}).get("button", "Buy"))
			b.text = label if why == "" else ("Got it!" if why == "You have this one" else why)
			b.disabled = why != ""
			b.pressed.connect(buy.bind(id))
		b.name = "Button " + id
		row.add_child(b)
		_rows.add_child(row)
		if first == null and not b.disabled:
			first = b
	(first if first else _close).grab_focus.call_deferred()


func decorate(part: String, step: int) -> void:
	# The Decorate spot's arrows: the next colour for a part of the room, or the next thing for a spot
	var DecorScript := load("res://scripts/home_decor.gd")
	if DecorScript.COLORS.has(part):
		Game.home[part] = posmod(int(Game.home.get(part, 0)) + step, DecorScript.COLORS[part].size())
	else:
		var items_: Array = DecorScript.ITEMS
		var now: String = DecorScript.item_in(part)
		Game.home[part] = items_[posmod(items_.find(now) + step, items_.size())]
	_keep_focus = "Button %s %d" % [part, step]
	Game.equipment_changed.emit()
	Game.save_game()
	_fill()


func _fill_decorate() -> void:
	# A line for each colour (walls, floor, rug, blanket) and each spot round the room, with arrows
	var DecorScript := load("res://scripts/home_decor.gd")
	_title.text = "Decorate your house"
	_blurb.text = "Pick the colours, and what goes where."
	_wallet.text = ""
	for c in _rows.get_children():
		c.queue_free()
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 36)
	_rows.add_child(columns)
	var left := VBoxContainer.new()
	var right := VBoxContainer.new()
	for col in [left, right]:
		col.add_theme_constant_override("separation", 8)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		columns.add_child(col)
	var lines := []
	for part in ["walls", "floor", "rug", "blanket"]:
		var names: Array = DecorScript.COLOR_NAMES[part]
		lines.append([part, "%s:  %s" % [DecorScript.LABELS[part], names[int(Game.home.get(part, 0)) % names.size()]], left])
	for spot in DecorScript.SPOTS:
		lines.append([spot, "%s:  %s" % [DecorScript.SPOT_NAMES[spot], DecorScript.ITEM_NAMES[DecorScript.item_in(spot)]], right])
	var first: Button = null
	for line in lines:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var label := Label.new()
		label.text = line[1]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.add_theme_font_size_override("font_size", roundi(18 * Settings.text_scale))
		for step in [-1, 1]:
			var b := Button.new()
			b.text = "◀" if step < 0 else "▶"
			b.name = "Button %s %d" % [line[0], step]
			b.custom_minimum_size.x = roundi(52 * Settings.text_scale)
			b.add_theme_font_size_override("font_size", roundi(18 * Settings.text_scale))
			b.pressed.connect(decorate.bind(line[0], step))
			if step < 0:
				row.add_child(b)
				row.add_child(label)
			else:
				row.add_child(b)
				if first == null:
					first = b
		(line[2] as VBoxContainer).add_child(row)
		var kept := row.get_node_or_null(_keep_focus) as Button
		if kept:
			first = kept
	_keep_focus = ""
	(first if first else _close).grab_focus.call_deferred()


func _fill_wardrobe() -> void:
	# Who's being dressed, a line for each clothing slot (what they're wearing, with arrows to swap it for something
	# else Nina owns), then their looks (arrows through the colours)
	var name: String = Rides.ride(who).rider
	_title.text = "Your Wardrobe" if who == "hero" else "%s's Wardrobe" % name
	_blurb.text = "Mix and match, for you or a friend! Buy more at the Clothing Boutique in the Market."
	_wallet.text = ""
	for c in _rows.get_children():
		c.queue_free()
	var first: Button = null
	# Two columns side by side, so it all fits: who and their clothes on the left, their looks on the right
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 36)
	_rows.add_child(columns)
	var left := VBoxContainer.new()
	var right := VBoxContainer.new()
	for col in [left, right]:
		col.add_theme_constant_override("separation", 8)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		columns.add_child(col)
	var lines := [["who", "Who:  " + name, Clothes.WHO.size() > 1, cycle_who]]
	var outfit: Dictionary = Game.outfits.get(who, {})
	for slot in Clothes.SLOTS:
		var id: String = outfit.get(slot, "")
		var text := "%s:  %s" % [Clothes.SLOT_NAMES[slot], items[id].name if items.has(id) else "their own"]
		if not Clothes.can_wear(who, slot):
			text = "%s:  (not for %s)" % [Clothes.SLOT_NAMES[slot], name]
		lines.append([slot, text, Clothes.can_wear(who, slot) and owned_for(slot).size() > 0, cycle.bind(slot)])
	var own_looks: Dictionary = Game.looks.get(who, {})
	for part in Clothes.looks_for(who):
		var pick := int(own_looks.get(part, 0))
		lines.append(["look " + part, "%s:  %s" % [Clothes.look_name(who, part), Clothes.COLOUR_NAMES[part][pick]],
			true, cycle_look.bind(part)])
	for line in lines:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var label := Label.new()
		label.text = line[1]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.add_theme_font_size_override("font_size", roundi(18 * Settings.text_scale))
		for step in [-1, 1]:
			var b := Button.new()
			b.text = "◀" if step < 0 else "▶"
			b.name = "Button %s %d" % [line[0], step]
			b.custom_minimum_size.x = roundi(52 * Settings.text_scale)
			b.add_theme_font_size_override("font_size", roundi(18 * Settings.text_scale))
			b.disabled = not line[2]
			b.pressed.connect((line[3] as Callable).bind(step))
			if step < 0:
				row.add_child(b)
				row.add_child(label)
			else:
				row.add_child(b)
				if first == null and not b.disabled:
					first = b
		(right if String(line[0]).begins_with("look ") else left).add_child(row)
		var kept := row.get_node_or_null(_keep_focus) as Button
		if kept:
			first = kept
	if who == "hero":
		# Back to the character creator (scripts/creator.gd) to change the hero themselves: body, hair, name and all
		var remake := Button.new()
		remake.text = "Change your hero..."
		remake.name = "Button remake"
		remake.add_theme_font_size_override("font_size", roundi(18 * Settings.text_scale))
		remake.pressed.connect(func() -> void:
			close()
			Creator.open())
		left.add_child(remake)
	_keep_focus = ""
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
	_panel.custom_minimum_size.x = roundi((1000 if _stall in ["Wardrobe", "Decorate"] else 640) * Settings.text_scale)
	_title.add_theme_font_size_override("font_size", roundi(30 * Settings.text_scale))
	_title.add_theme_color_override("font_color", Color(1, 0.9, 0.6))
	_blurb.add_theme_font_size_override("font_size", roundi(18 * Settings.text_scale))
	_wallet.add_theme_font_size_override("font_size", roundi(20 * Settings.text_scale))
	_wallet.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
	_note.add_theme_font_size_override("font_size", roundi(18 * Settings.text_scale))
	_note.add_theme_color_override("font_color", Color(0.75, 1.0, 0.8))
	_close.add_theme_font_size_override("font_size", roundi(19 * Settings.text_scale))
