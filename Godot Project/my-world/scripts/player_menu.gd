extends CanvasLayer

# Autoload "PlayerMenu": one menu for everything the player looks at or changes, on sheets side by side:
#   Quests · Map · Hero · Bag · Skate · Settings · Save
# Tab (Back on a controller; both can be changed in Settings > Controls) opens it on Quests. The old keys still go
# straight to their sheet: Q (the quest log) and M (the map, LB on a controller), and pressing one again on its own
# sheet closes the menu, like they used to. Inside it, Q / E or LB / RB go from sheet to sheet, the mouse clicks the
# tabs, and the arrows or the d-pad and Enter or A work the buttons. Tab, Esc and B close it. The game is paused under
# it, and it won't open in a conversation, the character creator, a shop or over the pause menu.
#
# The sheets show the game's own screens rather than copies of them: the quest log (scripts/quests.gd log_view()),
# the big map (scripts/map_screen.gd map_view()), the pause menu's settings tabs (scripts/pause_menu.gd
# settings_into()), and buttons that open the wardrobe (scripts/shop.gd) and the character creator, start Coach
# Rook's skate lesson and show the how-to tips again.

signal sheet_changed(sheet: String)

const SHEETS := [["quests", "Quests"], ["goals", "Goals"], ["map", "Map"], ["hero", "Hero"], ["bag", "Bag"],
	["skate", "Skate"], ["settings", "Settings"], ["save", "Save"]]
const HOTKEYS := {"quest_log": "quests", "map": "map"}      # old keys that open the menu straight on their sheet
const SCROLL_SPEED := 700.0                                 # pixels a second, scrolling a long sheet with the stick

var sheet := "quests"
var root: Control
var _tab_row: HBoxContainer
var _tab_buttons := {}                  # sheet -> its tab Button
var _prev_hint: Label
var _next_hint: Label
var _body: VBoxContainer                # the sheet's contents, built fresh each time it's shown
var _hint: Label
var _scroll: ScrollContainer            # a long sheet that the stick and arrows scroll
var _note: Label                        # "Saved!" and the like on the Save sheet
var _confirm_new := false
var _suppress_sound := false


func _ready() -> void:
	layer = 45                                              # over the HUD and shops, under the pause menu
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	Settings.changed.connect(_apply_look)
	Settings.device_changed.connect(_update_hints)
	_apply_look()


func is_open() -> bool:
	return root.visible


func showing(which: String) -> bool:
	return is_open() and sheet == which


func can_open() -> bool:
	# Not over the pause menu or a bed (they pause the game), a conversation, the character creator, a shop or the
	# wardrobe, or Coach Bruno's offer of a lesson
	return not get_tree().paused and not Dialogue.is_active() and not Creator.is_open() and not Shop.is_open() \
		and not SkateLesson.is_offering()


# ----------------------------------------------------------------------------- open / close
func open(at := "quests") -> void:
	if is_open():
		show_sheet(at)
		return
	if not can_open():
		return
	root.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Audio.play("ui_accept", -4.0, 0.0)
	show_sheet(at)


func close() -> void:
	if not is_open():
		return
	_clear()
	root.visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Audio.play("ui_back", -4.0, 0.0)


func toggle_sheet(which: String) -> void:
	# A sheet's own key: opens the menu there, or goes there, or (already there) closes the menu
	if showing(which):
		close()
	elif is_open():
		show_sheet(which)
	else:
		open(which)


func step(by: int) -> void:
	var i := _index(sheet) + by
	if i >= 0 and i < SHEETS.size():
		show_sheet(SHEETS[i][0])


func _index(which: String) -> int:
	for i in SHEETS.size():
		if SHEETS[i][0] == which:
			return i
	return -1


func _input(event: InputEvent) -> void:
	Settings.note_device(event)
	if PauseMenu.is_rebinding():
		return                                              # a new key or button for the Settings sheet: let it through
	if not is_open():
		# Tab here, before the menus' own focus moving can take it (Q and M wait for _unhandled_input, below)
		if event.is_action_pressed("player_menu") and can_open():
			get_viewport().set_input_as_handled()
			open("quests")
		return
	var by := 0
	if event.is_action_pressed("menu_prev"):
		by = -1
	elif event.is_action_pressed("menu_next"):
		by = 1
	var hot := ""
	for action in HOTKEYS:
		if event.is_action_pressed(action):
			hot = HOTKEYS[action]
	if by != 0:
		# Q is the quest log's key too: on the first sheet (Quests) there's nowhere back to go, so it closes, like
		# the quest log always did. LB (the map) on the first sheet does nothing.
		get_viewport().set_input_as_handled()
		var i := _index(sheet) + by
		if i >= 0 and i < SHEETS.size():
			step(by)
		elif hot == sheet:
			close()
	elif hot != "":
		get_viewport().set_input_as_handled()
		toggle_sheet(hot)
	elif event.is_action_pressed("player_menu") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		close()
	elif event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_B:
		get_viewport().set_input_as_handled()              # controller B (Godot's ui_cancel is only Esc)
		close()


func _unhandled_input(event: InputEvent) -> void:
	# The old keys, from the game: Q for the quest log, M for the map. After the screens on top (a name being typed in
	# the creator, say) have had them.
	if is_open() or not can_open():
		return
	for action in HOTKEYS:
		if event.is_action_pressed(action):
			get_viewport().set_input_as_handled()
			open(HOTKEYS[action])
			return


func _process(delta: float) -> void:
	if not is_open() or _scroll == null or not is_instance_valid(_scroll):
		return
	# A long sheet with nothing to pick in it (the quest log, the bag) scrolls with the stick, the d-pad or the arrows
	var owner := get_viewport().gui_get_focus_owner()
	if owner == null or _tab_buttons.values().has(owner):
		var dy := Input.get_axis("ui_up", "ui_down")
		if dy != 0.0:
			_scroll.scroll_vertical += roundi(dy * SCROLL_SPEED * delta / maxf(Engine.time_scale, 0.1))


# ----------------------------------------------------------------------------- sheets
func show_sheet(which: String) -> void:
	if _index(which) < 0:
		return
	var changed := which != sheet
	sheet = which
	_confirm_new = false
	for s in _tab_buttons:
		(_tab_buttons[s] as Button).set_pressed_no_signal(s == sheet)
	_fill()
	if changed:
		Audio.play("ui_move", -8.0, 0.0)
	sheet_changed.emit(sheet)


func _clear() -> void:
	# The quest log and the map belong to their own scripts: they're only lent to the sheet
	_scroll = null
	_note = null
	for v in [Quests.log_view_node(), TownMap.map_view_node()]:
		if v and v.get_parent():
			v.get_parent().remove_child(v)
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()


func _fill() -> void:
	_clear()
	var first: Control = null
	match sheet:
		"quests":
			first = _sheet_quests()
		"goals":
			first = _sheet_goals()
		"map":
			first = _sheet_map()
		"hero":
			first = _sheet_hero()
		"bag":
			first = _sheet_bag()
		"skate":
			first = _sheet_skate()
		"settings":
			first = _sheet_settings()
		"save":
			first = _sheet_save()
	_focus(first if first else _tab_buttons[sheet])
	_update_hints()


func _sheet_quests() -> Control:
	_scroll = _scroller()
	var box := _scroll.get_child(0) as VBoxContainer
	box.add_child(Quests.log_view())
	# Buttons under the log: skip a step of a quest that allows it (the First Night), or start the First Night on a
	# save that's never had it (it's offered, never forced: scripts/first_night.gd). The tab keeps the focus, so the
	# log opens at the top.
	for id in Quests._order:
		if Quests.is_started(id) and Quests.can_skip(id):
			var q_name := str(Quests.quest(id).get("name", id))
			var b := _button("Skip this step of %s" % q_name, func():
				Quests.skip(id)
				_fill(), box)
			b.name = "Skip " + id
	if not Quests.is_started(FirstNight.ID) and not Game.needs_creator:
		var b := _button("Start The First Night (a guided first hour)", func():
			FirstNight.start()
			_fill(), box)
		b.name = "Start first_night"
	return null


func _sheet_goals() -> Control:
	# What to aim for next, across everything (scripts/nights.gd goals()): tonight, next, and tomorrow night
	_scroll = _scroller()
	var box := _scroll.get_child(0) as VBoxContainer
	for part in Nights.goals():
		_heading(str(part[0]), box, 26)
		for text in part[1]:
			var r := RichTextLabel.new()
			r.bbcode_enabled = true
			r.fit_content = true
			r.scroll_active = false
			r.text = str(text)
			r.add_theme_font_size_override("normal_font_size", _fs(20))
			r.add_theme_font_size_override("bold_font_size", _fs(22))
			box.add_child(r)
		_gap(box)
	return null


func _sheet_map() -> Control:
	var view := TownMap.map_view()
	_body.add_child(view)
	return null


func _sheet_hero() -> Control:
	var hero: Dictionary = Game.hero
	_heading(Hero.display_name(hero))
	var body: Dictionary = Hero.body_of(hero)
	_line("%s / %s   ·   %s" % [Hero.pronoun(hero, "they").capitalize(), Hero.pronoun(hero, "them"), body.get("name", "")])
	_line("Level %d   ·   XP %d / %d   ·   HP %d / %d   ·   MP %d / %d" % [Game.level, Game.xp, Game.xp_to_next(), Game.hp,
		Game.max_hp, Game.mp, Game.max_mp])
	var worn := []
	for slot in Game.outfit:
		var id := str(Game.outfit[slot])
		if id != "" and Shop.items.has(id):
			worn.append(str(Shop.items[id].name))
	_line("Wearing: " + (", ".join(worn) if not worn.is_empty() else "your own look"), true)
	_gap()
	var first := _button("Your wardrobe", func():
		close()
		Shop.open("Wardrobe"))                              # (scripts/shop.gd: what you and your friends wear)
	first.name = "Wardrobe"
	var remake := _button("Change your hero...", func():
		close()
		Creator.open())                                     # back to the character creator: body, hair, name and all
	remake.name = "Change hero"
	remake.disabled = get_tree().get_first_node_in_group("player") == null
	return first


func _sheet_bag() -> Control:
	_scroll = _scroller()
	var box := _scroll.get_child(0) as VBoxContainer
	var wallet := _heading("✦ %d sparkle%s" % [Game.sparkles, "" if Game.sparkles == 1 else "s"], box)
	wallet.name = "Sparkles"
	wallet.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
	_line("Bits of broken time. Find them round town and from quests, and spend them at the Market.", true, box)
	var things := []
	var clothes := []
	var places := []
	for id in Game.items:
		if id.begins_with("happy_place:"):                  # found, not carried (scripts/happy_place.gd)
			places.append(id.get_slice(":", 1).capitalize())
			continue
		var item: Dictionary = Shop.items.get(id, {})
		var name := str(item.get("name", id.capitalize()))
		(clothes if Shop.wearable(id) else things).append(name)
	_gap(box)
	_heading("Things", box, 26)
	var t := _line(", ".join(things) if not things.is_empty() else "Nothing yet. There's a skateboard at the Skate Park!", true, box)
	t.name = "Things"
	_gap(box)
	_heading("Clothes (%d)" % clothes.size(), box, 26)
	_line(", ".join(clothes) if not clothes.is_empty() else "Only what you're wearing. The Clothing Boutique sells more!", true, box)
	if not places.is_empty():
		_gap(box)
		_heading("Happy places found (%d)" % places.size(), box, 26)
		_line(", ".join(places), true, box)
	_gap(box)
	_gadgets_page(box)
	_gap(box)
	_watches_page(box)
	return null


func _gadgets_page(box: VBoxContainer) -> Control:
	# Her gadgets (scripts/arsenal.gd): each one's version, ammo and upgrades, and a button for each of its two mod
	# slots that swaps in the next mod she owns (or nothing). Says what the mods and the combo do.
	var head := _heading("Gadgets", box, 26)
	head.name = "Gadgets"
	if Arsenal.mods_owned.is_empty():
		_line("Mods slot into any gadget, two each. Dash sells them at his workbench, beside his gadget stall.", true, box)
	var first: Control = null
	for id in Arsenal.owned:
		var am := Arsenal.ammo_of(id)
		var ups: Array[String] = []
		for k in Arsenal.upgrade_kinds(id):
			if Arsenal.upgrade_level(id, k) > 0:
				ups.append("%s %d" % [str(Arsenal.UPGRADES[k].name), Arsenal.upgrade_level(id, k)])
		_line("%s  V%d   ·   %s%s" % [Arsenal.gadget_name(id), Arsenal.level(id), "∞" if am < 0 else "%d / %d" % [am,
			Arsenal.max_ammo(id)], ("   ·   " + ", ".join(ups)) if not ups.is_empty() else ""], true, box)
		if Arsenal.mods_owned.is_empty():
			continue
		var row := HBoxContainer.new()
		row.name = "Mods " + id
		row.add_theme_constant_override("separation", _fs(10))
		box.add_child(row)
		var combo := _line("", true, box)
		var show := func() -> void:
			var c := Arsenal.combo_key(id)
			var ms := Arsenal.mods(id)
			var words := []
			for m in ms:
				words.append("%s: %s" % [Arsenal.MODS[m].name, Arsenal.MODS[m].says])
			if Arsenal.COMBOS.has(c):
				words.append("Combo, %s! %s" % [Arsenal.COMBOS[c].name, Arsenal.COMBOS[c].says])
			combo.text = "\n".join(words) if not words.is_empty() else "No mods in it yet."
		show.call()
		for i in Arsenal.SLOTS:
			var slot := i
			var b := _button("", func(): pass, row)
			b.name = "Slot %s %d" % [id, slot]
			b.custom_minimum_size = Vector2(_fs(250), _fs(42))
			var label := func() -> void:
				var m := str(Arsenal.slots_of(id)[slot])
				b.text = "Mod %d: %s" % [slot + 1, str(Arsenal.MODS[m].name) if m != "" else "(empty)"]
			label.call()
			b.pressed.connect(func():
				Arsenal.cycle_mod(id, slot)
				for k in Arsenal.SLOTS:
					var other := row.get_node_or_null("Slot %s %d" % [id, k]) as Button
					if other:
						var m := str(Arsenal.slots_of(id)[k])
						other.text = "Mod %d: %s" % [k + 1, str(Arsenal.MODS[m].name) if m != "" else "(empty)"]
				show.call()
				Game.save_game())
			if first == null:
				first = b
	return first


func _watches_page(box: VBoxContainer) -> void:
	# The lost watches (scripts/watches.gd): a picture of each one found, a dark outline of each still out there, and
	# a few words about whichever is picked (where it was, or a vague hint)
	var found := Watches.found_count()
	var given := Watches.given_count()
	var head := _heading("Lost watches: %d of %d found" % [found, Watches.WATCHES.size()], box, 26)
	head.name = "Watches"
	var nxt := Watches.next_reward()
	var about := "Chosen kids lost these when they landed. Dash collects them."
	if given > 0:
		about += " You've given him %d." % given
	if not Watches.to_give().is_empty():
		about += " Talk to Dash: you have %d for him!" % Watches.to_give().size()
	elif not nxt.is_empty() and found > 0:
		about += " At %d he has %s for you." % [int(nxt.at), nxt.text]
	_line(about, true, box)
	var grid := GridContainer.new()
	grid.name = "Watch Grid"
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", _fs(8))
	grid.add_theme_constant_override("v_separation", _fs(8))
	box.add_child(grid)
	var detail := _line("Pick a watch to see more.", true, box)
	detail.name = "Watch Detail"
	detail.custom_minimum_size.y = _fs(60)
	for w in Watches.WATCHES:
		var have := Watches.is_found(w.id)
		var cell := Button.new()
		cell.name = str(w.id)
		cell.custom_minimum_size = Vector2(_fs(112), _fs(132))
		var inner := VBoxContainer.new()
		inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.alignment = BoxContainer.ALIGNMENT_CENTER
		cell.add_child(inner)
		var pic := SubViewportContainer.new()
		pic.stretch = true
		pic.custom_minimum_size = Vector2(_fs(96), _fs(96))
		pic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pic.add_child(Watches.icon_viewport(str(w.id), have, _fs(96)))
		inner.add_child(pic)
		var label := Label.new()
		label.text = str(w.name) if have else "???"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", _fs(13))
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(label)
		var words := ("%s. %s\n%s%s" % [w.name, w.note, w.place, "  (given to Dash)" if Watches.is_given(w.id) else ""]) \
			if have else "Still lost. Hint: " + str(w.hint)
		cell.focus_entered.connect(func(): detail.text = words)
		cell.mouse_entered.connect(func(): detail.text = words)
		grid.add_child(cell)
	if Game.has_item("popper_colour:clockwork"):
		_gap(box)
		var colours: Array = StarPopper.COLOURS.keys().filter(func(c: String) -> bool:
			return c == "classic" or Game.has_item("popper_colour:" + c))
		var popper := _button("Star Popper colour: %s" % Game.popper_colour.capitalize(), func(): pass, box)
		popper.name = "Popper Colour"
		popper.pressed.connect(func():
			Game.popper_colour = colours[(colours.find(Game.popper_colour) + 1) % colours.size()]
			popper.text = "Star Popper colour: %s" % Game.popper_colour.capitalize()
			Game.equipment_changed.emit()
			Game.save_game())


func _sheet_skate() -> Control:
	_scroll = _scroller()
	var box := _scroll.get_child(0) as VBoxContainer
	var first: Control = null
	_heading("Coach Bruno's skate lesson", box, 26)
	if not Game.has_item("skateboard"):
		_line("Pick up the skateboard in the middle of the Skate Park first, then Rook can teach you!", true, box)
	else:
		var done := 0
		var steps := []
		for s in SkateLesson.STEPS:
			var ok := Dialogue.flags.has("skate_lesson_" + s.id)
			done += 1 if ok else 0
			steps.append(("✓ " if ok else "○ ") + str(s.id).capitalize())
		_line("%d of %d steps done:   %s" % [done, steps.size(), "   ".join(steps)], true, box)
		var text := "Stop the skate lesson" if SkateLesson.active else ("Take the lesson again" if SkateLesson.is_done()
			else ("Carry on with the lesson" if done > 0 else "Start the skate lesson"))
		first = _button(text, func():
			close()
			if SkateLesson.active:
				SkateLesson.stop()
			else:
				SkateLesson.start(), box)
		first.name = "Lesson"
	_gap(box)
	# Your rides: the skateboard, and any built at Zippy's Tune-Up from a schematic (scripts/schematics.gd)
	_heading("Your ride", box, 26)
	var row := HFlowContainer.new()                        # wraps onto a second line when there are lots
	row.name = "Rides"
	row.add_theme_constant_override("h_separation", 10)
	row.add_theme_constant_override("v_separation", 8)
	box.add_child(row)
	for r in Schematics.rides_owned():
		var ride: Dictionary = Rides.HERO_RIDES[r]
		var on := Game.hero_ride == r
		var b := _button(("✓ " if on else "") + str(ride.name), func():
			Schematics.use_ride(r)
			show_sheet("skate"), row)
		b.name = "Ride " + r
		b.custom_minimum_size.x = _fs(210)
		b.disabled = on
	var locked := Rides.HERO_ORDER.size() - Schematics.rides_owned().size()
	if locked > 0:
		_line("%s ride%s still to unlock: find %s schematic%s round Galaxity, and Zippy builds %s at the Tune-Up." % [
			locked, "" if locked == 1 else "s", "its" if locked == 1 else "their", "" if locked == 1 else "s",
			"it" if locked == 1 else "them"], true, box)
	_gap(box)
	_heading("Skate Park goals", box, 26)
	var Goals := load("res://scripts/skate_goals.gd")
	var letters := 0
	for l in Goals.LETTERS:
		letters += 1 if Dialogue.flags.has("skate_letter_" + l) else 0
	for g in Goals.GOALS:
		var ok := Dialogue.flags.has("skate_goal_" + g.id)
		var extra := "  (%d of 5 letters)" % letters if g.id == "letters" and not ok else ""
		_line("%s %s   ✦ %d%s" % ["✓" if ok else "○", g.text, g.sparkles, extra], false, box)
	_gap(box)
	_heading("How-to tips", box, 26)
	var tips := _button("Show the how-to tips again", func():
		close()
		Tips.replay(), box)
	tips.name = "Tips"
	return first if first else tips


func _sheet_settings() -> Control:
	var holder := VBoxContainer.new()
	holder.name = "Settings"
	holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	holder.add_theme_constant_override("separation", 10)
	_body.add_child(holder)
	var tabs := PauseMenu.settings_into(holder)
	return tabs.get_tab_bar()


func _sheet_save() -> Control:
	_heading("Your game")
	_line("It saves by itself every little while, and when you quit.", true)
	_gap()
	var first := _button("Save now", func():
		Game.save_game()
		if _note:
			_note.text = "Saved! ✓")
	first.name = "Save now"
	for way in PauseMenu.way_home():
		_button(way[0], func():
			close()
			(way[1] as Callable).call())
	var again := _button("New game...", func():
		_confirm_new = true
		_fill_confirm())
	again.name = "New game"
	var quit := _button("Save and quit", func():
		Game.save_game()
		get_tree().quit())
	quit.name = "Quit"
	_note = _line("", false)
	_note.add_theme_color_override("font_color", Color(0.75, 1.0, 0.8))
	return first


func _fill_confirm() -> void:
	_clear()
	_heading("Start a new game?")
	_line("This erases your saved progress: your hero, level, sparkles and items.", true)
	_gap()
	var keep := _button("No, keep playing", func(): show_sheet("save"))
	keep.name = "Keep playing"
	_button("Yes, start over", func():
		close()
		Game.new_game())
	_focus(keep)


# ----------------------------------------------------------------------------- building blocks
func _scroller() -> ScrollContainer:
	var s := ScrollContainer.new()
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	s.follow_focus = true
	_body.add_child(s)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8)
	s.add_child(box)
	return s


func _heading(text: String, parent: Node = null, size := 32) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", _fs(size))
	l.add_theme_color_override("font_color", Color(1, 0.9, 0.6))
	(parent if parent else _body).add_child(l)
	return l


func _line(text: String, wrap := false, parent: Node = null) -> Label:
	var l := Label.new()
	l.text = text
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = _fs(300)
	(parent if parent else _body).add_child(l)
	return l


func _gap(parent: Node = null) -> void:
	var c := Control.new()
	c.custom_minimum_size.y = _fs(8)
	(parent if parent else _body).add_child(c)


func _button(text: String, cb: Callable, parent: Node = null) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(_fs(320), _fs(46))
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.pressed.connect(func():
		Audio.play("ui_accept", -4.0, 0.0)
		cb.call())
	b.focus_entered.connect(func(): if not _suppress_sound: Audio.play("ui_move", -8.0, 0.0))
	(parent if parent else _body).add_child(b)
	return b


func _focus(c: Control) -> void:
	if c == null or not is_instance_valid(c):
		return
	_suppress_sound = true
	c.grab_focus()
	_suppress_sound = false


func _fs(px: float) -> int:
	return roundi(px * Settings.text_scale)


func switch_prompts() -> String:
	return "LB / RB" if Settings.last_device == "pad" else "Q / E"


func _update_hints() -> void:
	var pad := Settings.last_device == "pad"
	_prev_hint.text = "◀ " + ("LB" if pad else "Q")
	_next_hint.text = ("RB" if pad else "E") + " ▶"
	var pick := "A: pick" if pad else "Enter or click: pick"
	_hint.text = "%s: change sheet      %s      %s: close" % [switch_prompts(), pick, Settings.prompt("player_menu")]


# ----------------------------------------------------------------------------- look
func _build() -> void:
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.visible = false
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.02, 0.1, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var outer := MarginContainer.new()
	outer.name = "Outer"
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(outer)
	var panel := PanelContainer.new()
	outer.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	panel.add_child(margin)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	margin.add_child(v)
	# The tabs along the top, with which keys go left and right
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	v.add_child(top)
	_prev_hint = Label.new()
	_prev_hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(_prev_hint)
	_tab_row = HBoxContainer.new()
	_tab_row.name = "Tabs"
	_tab_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_tab_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tab_row.add_theme_constant_override("separation", 6)
	top.add_child(_tab_row)
	for pair in SHEETS:
		var which: String = pair[0]
		var b := Button.new()
		b.name = "Tab " + which
		b.text = pair[1]
		b.toggle_mode = true
		b.pressed.connect(func():
			b.set_pressed_no_signal(true)                   # clicking the open tab keeps it lit
			show_sheet(which))
		b.focus_entered.connect(func(): if not _suppress_sound: Audio.play("ui_move", -8.0, 0.0))
		_tab_row.add_child(b)
		_tab_buttons[which] = b
	_next_hint = Label.new()
	_next_hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(_next_hint)
	v.add_child(HSeparator.new())
	_body = VBoxContainer.new()
	_body.name = "Sheet"
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 10)
	v.add_child(_body)
	_hint = Label.new()
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.modulate = Color(1, 1, 1, 0.8)
	v.add_child(_hint)


func _apply_look() -> void:
	root.theme = PauseMenu.make_theme()
	var outer := root.get_node("Outer") as MarginContainer
	for side in ["left", "right"]:
		outer.add_theme_constant_override("margin_" + side, _fs(48))
	for side in ["top", "bottom"]:
		outer.add_theme_constant_override("margin_" + side, _fs(32))
	for b in _tab_buttons.values():
		(b as Button).custom_minimum_size = Vector2(_fs(118), _fs(46))
	_hint.add_theme_font_size_override("font_size", _fs(17))
	_update_hints()
