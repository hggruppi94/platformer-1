extends Node

# Autoload "Creator": the character creator, like an RPG's. The player makes their own hero (scripts/hero.gd,
# Game.hero): a human kid, a girl or a boy (big buttons on the Body tab), their skin tone and size, face, hairstyle
# (ten for girls and ten for boys, scripts/hair_kit.gd, or all twenty with "Show every style"), colours, clothes,
# name and pronouns. It opens when a new game starts (and once for a save from before heroes: scripts/player.gd),
# and any time from the wardrobe (scripts/shop.gd).
#
# The hero stands in the world on a turntable (drag with the mouse, or the turn buttons) while a panel down the left
# changes them; every change shows straight away. The game carries on behind (it isn't paused), but the hero can't
# move until it's done.
#
# Secret bodies (Hero.SECRETS) aren't offered any more (Hero.SECRET_ORDER is empty): there's one body, a human kid.

signal closed

const TABS := ["Body", "Face", "Hair", "Colours", "Clothes", "Void", "Name"]
const VOID_LOOK := preload("res://scripts/void_look.gd")   # (the Void tab only shows once they've been to the Void)
const FACE_PARTS := ["eyes", "blush", "brows"]          # (skin is on the Body tab, with the skin tones)
const CLOTHES_PARTS := ["top", "bottoms", "shoes"]

var _layer: CanvasLayer
var _panel: PanelContainer
var _tabs: HBoxContainer
var _content: VBoxContainer
var _warn: Label
var _tab := "Body"
var _part := "fur"                     # the colour being picked on the Colours tab
var _cloth_part := "top"               # ...and on the Clothes tab
var _first_time := false
var _all_hair := false                 # the Hair tab shows all twenty styles, not just the girls' or boys' ten
var _cam: Camera3D
var _old_cam: Camera3D
var _player: Node3D
var _dragging := false
var _void_shown := false               # the turntable's hero has their Void look on for the Void tab


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	Dialogue.flag_set.connect(func(_f: String) -> void: check_secrets.call_deferred())
	Game.saved.connect(func() -> void: check_secrets.call_deferred())


func check_secrets() -> void:
	# A secret body whose condition's been met is found: it's kept in the save, and the player hears about it once
	for id in Hero.SECRET_ORDER:
		if not Game.has_item("secret:" + id) and Hero.meets(id):
			Game.give_item("secret:" + id)
			Game.message("Secret hero found: %s! Pick it in \"Change your hero...\" at the wardrobe." % Hero.BODIES[id].name)


func is_open() -> bool:
	return _layer.visible


func previewing_void() -> bool:
	# On the Void tab the hero on the turntable shows their Void look, even on Earth (scenes/player/player.gd)
	return is_open() and _tab == "Void"


func tabs() -> Array:
	return TABS.filter(func(t: String) -> bool: return t != "Void" or VOID_LOOK.has_look(Game.hero))


func open(first_time := false) -> void:
	_player = get_tree().get_first_node_in_group("player") as Node3D
	if is_open() or _player == null:
		return
	_first_time = first_time
	_tab = "Body" if first_time else _tab
	Game.hold_controls(&"creator", true, _player)
	# Off the ride first: on it, the skating (scenes/player/skate.gd) keeps turning them back the way they're rolling
	if Game.riding:
		Game.toggle_skateboard()
	# If the scene changes while it's open (New Game from the pause menu, say), this hero and camera go with it
	if not _player.tree_exiting.is_connected(_abandon):
		_player.tree_exiting.connect(_abandon)
	if _player.get("rider") != "hero":
		_player.call("set_rider", "hero", false)
	# At home they step onto the rug to be made (clear of the bed and its prompt), facing the door
	var stage := get_tree().current_scene.find_child("CreatorSpot", true, false) as Node3D
	if stage:
		_player.global_position = stage.global_position
		(_player.get_node("Visual") as Node3D).rotation.y = 0.0
	# A camera in front of the hero, looking at them; they turn to face it
	_old_cam = get_viewport().get_camera_3d()
	_cam = Camera3D.new()
	_cam.fov = 40
	get_tree().current_scene.add_child(_cam)
	var visual := _player.get_node("Visual") as Node3D
	var front := Vector3(sin(visual.rotation.y), 0, cos(visual.rotation.y))
	_cam.global_position = _player.global_position + front * 3.3 + Vector3(0, 0.35, 0) + _side(front) * 0.9
	_cam.look_at(_player.global_position + Vector3(0, -0.05, 0) + _side(front) * 0.9)
	_cam.make_current()
	var hud := _player.get_node_or_null("HUD") as CanvasLayer
	if hud:
		hud.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_layer.visible = true
	_fill()
	Audio.play("ui_accept", -4.0, 0.0)


func _side(front: Vector3) -> Vector3:
	# The hero stands a bit to the right of the middle of the screen, clear of the panel on the left
	return front.cross(Vector3.UP).normalized()


func close() -> void:
	if not is_open():
		return
	if Hero.display_name(Game.hero) == "You" and str(Game.hero.get("name", "")).strip_edges() == "":
		_tab = "Name"
		_fill()
		_warn.text = "What's your name? Type it in before you go!"
		return
	_layer.visible = false
	_show_void()
	Game.needs_creator = false
	if _player and is_instance_valid(_player) and _player.tree_exiting.is_connected(_abandon):
		_player.tree_exiting.disconnect(_abandon)
	if _cam:
		_cam.queue_free()
		_cam = null
	if _old_cam and is_instance_valid(_old_cam):
		_old_cam.make_current()
	if _player and is_instance_valid(_player):
		Game.hold_controls(&"creator", false, _player)
		var hud := _player.get_node_or_null("HUD") as CanvasLayer
		if hud:
			hud.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Game.save_game()
	if _first_time and not Clock.on_earth:
		# (On Earth a new game's opening shows all this instead: a cutscene and the movement tutorial,
		# scripts/opening.gd, started by FirstNight when this closes)
		Game.message("Welcome to the Void, %s!" % Hero.display_name(Game.hero))
		Tips.basics()                              # how to walk, jump, open the map... (scripts/tips.gd)
	Audio.play("ui_accept", -4.0, 0.0)
	closed.emit()


func _abandon() -> void:
	# The hero being made is leaving (the scene is changing under the creator), so put the creator away without
	# saving. A new game's player opens it again when it arrives (scenes/player/player.gd).
	_layer.visible = false
	_dragging = false
	_void_shown = false
	_cam = null
	_old_cam = null
	_player = null


# -----------------------------------------------------------------------------
# Changing the hero
# -----------------------------------------------------------------------------
func set_value(key: String, value) -> void:
	Game.hero[key] = value
	_changed()


func set_color(part: String, pick: int) -> void:
	if not Game.hero.has("colors"):
		Game.hero["colors"] = {}
	# A skin (scripts/skins.gd) would hide the new colour, so picking one of the colours it covers takes it off
	if part in Skins.SKINS.get(str(Game.hero.get("skin", "")), {}).get("colors", {}):
		Game.hero.erase("skin")
	if pick <= 0:
		Game.hero.colors.erase(part)
	else:
		Game.hero.colors[part] = pick
	_changed()


func step_body(step: int) -> void:
	var bodies := Hero.choices(Game.hero)
	var i := bodies.find(str(Game.hero.get("body", "hippo")))
	Game.hero["body"] = bodies[posmod(i + step, bodies.size())]
	_player.call("set_rider", "hero", false)        # a new body is a new model
	_changed()


func set_girl(girl: bool) -> void:
	# Girl or boy: the body, the pronouns that go with it (unless they picked they/them) and, if their hairstyle is
	# one of the other's, the first of theirs
	if Hero.is_girl(Game.hero) == girl and str(Game.hero.get("body", "")) in Hero.BODY_ORDER:
		return
	Game.hero["body"] = "human_girl" if girl else "human_boy"
	if str(Game.hero.get("pronouns", "they")) != "they":
		Game.hero["pronouns"] = "she" if girl else "he"
	if not _all_hair and not int(Game.hero.get("hairstyle", 0)) in Hero.styles_for(Game.hero):
		Game.hero["hairstyle"] = Hero.blank(girl).hairstyle
	_player.call("set_rider", "hero", false)        # a new body is a new model
	_changed()


func step_hair(step: int) -> void:
	var styles := _hair_list()
	var i := styles.find(int(Game.hero.get("hairstyle", 0)))
	set_value("hairstyle", styles[posmod(i + step, styles.size())] if i >= 0 else styles[0])


func _hair_list() -> Array:
	return Hairstyles.GIRL_STYLES + Hairstyles.BOY_STYLES if _all_hair else Hero.styles_for(Game.hero)


func step_face(step: int) -> void:
	# The ready-made faces, one after another (from a face of their own, the next one along from the start)
	var i := FaceSculpt.preset_index(Game.hero)
	if i < 0:
		i = 0 if step > 0 else FaceSculpt.PRESETS.size()
	else:
		i += step
	FaceSculpt.apply_preset(Game.hero, posmod(i, FaceSculpt.PRESETS.size()))
	_changed()


func surprise() -> void:
	# A whole new look, but still them: their name, pronouns and girl or boy stay
	var keep := _keep()
	if VOID_LOOK.has_look(Game.hero):
		VOID_LOOK.pick_random(keep)              # (only once they've been to the Void)
	var girl := Hero.is_girl(Game.hero)
	for i in 8:
		Game.hero = Hero.random()
		if Hero.is_girl(Game.hero) == girl:
			break
	Game.hero["body"] = "human_girl" if girl else "human_boy"
	if not int(Game.hero.hairstyle) in Hero.styles_for(Game.hero):
		var styles := Hero.styles_for(Game.hero)
		Game.hero["hairstyle"] = styles[randi() % styles.size()]
	Game.hero.merge(keep, true)
	_player.call("set_rider", "hero", false)
	_changed()


func _keep() -> Dictionary:
	# What stays through Surprise me and Start over: their name and pronouns, and their Void look once they have one
	var keep := {"name": Game.hero.get("name", ""), "pronouns": Game.hero.get("pronouns", "they")}
	for k in ["void_feature", "void_glow"]:
		if Game.hero.has(k):
			keep[k] = Game.hero[k]
	return keep


func start_over() -> void:
	var keep := _keep()
	Game.hero = Hero.blank(Hero.is_girl(Game.hero))
	Game.hero.merge(keep, true)
	_player.call("set_rider", "hero", false)
	_changed()


func _changed() -> void:
	Game.equipment_changed.emit()
	_fill()


func _input(event: InputEvent) -> void:
	if not is_open() or get_tree().paused:
		return                                   # (the pause menu is on top: it has the mouse)
	# Drag anywhere off the panel to turn the hero round. Clicks and drags off the panel are the creator's, so they're
	# marked handled: otherwise the camera (scenes/player/spring_arm_3d.gd) takes a click in the world as "grab the
	# mouse" and the cursor vanishes.
	var off_panel := event is InputEventMouse and not _panel.get_global_rect().has_point(event.position)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed and off_panel
		if off_panel:
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and off_panel:
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _dragging:
		_turn(event.relative.x * 0.01)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func _process(delta: float) -> void:
	# The controller's right stick turns the hero too
	if is_open() and not get_tree().paused:
		var stick := Input.get_axis("look_left", "look_right")
		if stick != 0.0:
			_turn(stick * 2.6 * delta)


func _turn(amount: float) -> void:
	if _player and is_instance_valid(_player):
		(_player.get_node("Visual") as Node3D).rotation.y += amount


# -----------------------------------------------------------------------------
# The panel
# -----------------------------------------------------------------------------
func _build() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 40
	_layer.visible = false
	add_child(_layer)
	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	_panel.offset_left = 16
	_panel.offset_top = 16
	_panel.offset_bottom = -16
	_panel.custom_minimum_size.x = 520
	_panel.theme = UiStyle.theme(1.0, false, false)    # the shared menu look (scripts/ui_style.gd)
	var style := UiStyle.box(UiStyle.PANEL, 18, UiStyle.EDGE, 3)
	style.set_content_margin_all(18)
	_panel.add_theme_stylebox_override("panel", style)
	_layer.add_child(_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	_panel.add_child(v)
	var title := _label("Make your hero", 30, Color(1, 0.9, 0.6))
	v.add_child(title)
	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 6)
	v.add_child(_tabs)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 10)
	scroll.add_child(_content)
	_warn = _label("", 18, Color(1.0, 0.7, 0.6))
	v.add_child(_warn)
	var turn := HBoxContainer.new()
	turn.add_theme_constant_override("separation", 8)
	v.add_child(turn)
	turn.add_child(_button("⟲ Turn", func() -> void: _turn(-0.6), "Turn left"))
	turn.add_child(_button("Turn ⟳", func() -> void: _turn(0.6), "Turn right"))
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 8)
	v.add_child(bottom)
	bottom.add_child(_button("Surprise me!", surprise, "Surprise"))
	bottom.add_child(_button("Start over", start_over, "StartOver"))
	var done := _button("Done!", close, "Done")
	done.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(done)


func _show_void() -> void:
	# On and off the Void tab, the hero on the turntable puts their Void look on or takes it off
	if previewing_void() != _void_shown:
		_void_shown = previewing_void()
		Game.equipment_changed.emit()


func _fill() -> void:
	_warn.text = ""
	for c in _tabs.get_children():
		c.queue_free()
	if not _tab in tabs():
		_tab = "Body"
	for t in tabs():
		var b := _button(t, func() -> void:
			_tab = t
			_fill(), "Tab " + t)
		b.toggle_mode = true
		b.button_pressed = t == _tab
		_tabs.add_child(b)
	for c in _content.get_children():
		_content.remove_child(c)             # (out now, so the new rows keep their names)
		c.queue_free()
	var h: Dictionary = Game.hero
	var body := Hero.body_of(h)
	match _tab:
		"Body":
			# Girl or boy: two big buttons
			var pick := HBoxContainer.new()
			pick.add_theme_constant_override("separation", 12)
			for girl in [true, false]:
				var b := _button("Girl" if girl else "Boy", set_girl.bind(girl), "Pick " + ("girl" if girl else "boy"))
				b.toggle_mode = true
				b.button_pressed = Hero.is_girl(h) == girl
				b.custom_minimum_size = Vector2(0, 64)
				b.add_theme_font_size_override("font_size", 26)
				b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				pick.add_child(b)
			_content.add_child(pick)
			_content.add_child(_label("Skin", 20))
			_swatches("fur", Hero.SKIN_TONES)
			_slider("Height", "height", Hero.SIZES.height)
			_slider("Head size", "head", Hero.SIZES.head)
			_slider("Build", "build", Hero.SIZES.build)
		"Face":
			var face: Dictionary = body.get("face", {})
			var preset := FaceSculpt.preset_index(h)
			_arrows("Face", FaceSculpt.PRESETS[preset].name if preset >= 0 else "Your own", step_face)
			for key in FaceSculpt.KEYS:
				if FaceSculpt.has_feature(face, key):
					_slider(FaceSculpt.slider_name(face, key), key, FaceSculpt.RANGES[key], true)
		"Hair":
			# The styles as big buttons with their names, two to a row; the one they have lit up
			var styles := _hair_list()
			var now := int(h.get("hairstyle", 0))
			var grid := GridContainer.new()
			grid.name = "Hair styles"
			grid.columns = 2
			grid.add_theme_constant_override("h_separation", 8)
			grid.add_theme_constant_override("v_separation", 8)
			for style in styles:
				var b := _button(Hairstyles.name_of(style), set_value.bind("hairstyle", style), "Hair %d" % style)
				b.toggle_mode = true
				b.button_pressed = style == now
				b.custom_minimum_size = Vector2(0, 40)
				b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				grid.add_child(b)
			_content.add_child(grid)
			var about := _label(str(HairKit.ABOUT.get(Hairstyles.name_of(now), "")), 17, Color(0.85, 0.85, 1.0))
			about.name = "Hair about"
			_content.add_child(about)
			_content.add_child(_label("Hair colour", 20))
			_swatches("hair")
			var all := CheckButton.new()
			all.name = "All hair"
			all.text = "Show every style (girls' and boys')"
			all.button_pressed = _all_hair
			all.toggled.connect(func(on: bool) -> void:
				_all_hair = on
				_fill())
			_content.add_child(all)
		"Colours":
			_arrows("Colour of", Hero.COLOR_NAMES[_part], func(step: int) -> void:
				_part = FACE_PARTS[posmod(FACE_PARTS.find(_part) + step, FACE_PARTS.size())]
				_fill())
			_swatches(_part)
		"Clothes":
			_arrows("Colour of", "Their own " + _cloth_part, func(step: int) -> void:
				_cloth_part = CLOTHES_PARTS[posmod(CLOTHES_PARTS.find(_cloth_part) + step, CLOTHES_PARTS.size())]
				_fill())
			_swatches(_cloth_part)
			_content.add_child(_label("Clothes you own (buy more at the Clothing Boutique)", 18, Color(0.85, 0.85, 1.0)))
			var outfit: Dictionary = Game.outfits.get("hero", {})
			for slot in Clothes.SLOTS:
				var id: String = outfit.get(slot, "")
				var name: String = Shop.items[id].name if Shop.items.has(id) else "none"
				var row := _arrows(Clothes.SLOT_NAMES[slot], name, func(step: int) -> void:
					Shop.who = "hero"
					Shop.cycle(slot, step)
					_fill())
				for b in row.find_children("*", "Button", false, false):
					(b as Button).disabled = Shop.owned_for(slot).is_empty()
		"Void":
			_content.add_child(_label("When you cross into the Void you change a little: your watch on your wrist, a glow in your eyes and one alien feature. Pick yours!", 18, Color(0.85, 0.85, 1.0)))
			var grid := GridContainer.new()
			grid.name = "Void features"
			grid.columns = 2
			grid.add_theme_constant_override("h_separation", 8)
			grid.add_theme_constant_override("v_separation", 8)
			var now := VOID_LOOK.feature(h)
			for f in VOID_LOOK.FEATURES:
				var b := _button(VOID_LOOK.FEATURE_NAMES[f], set_value.bind("void_feature", f), "Void " + f)
				b.toggle_mode = true
				b.button_pressed = f == now
				b.custom_minimum_size = Vector2(0, 44)
				b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				grid.add_child(b)
			_content.add_child(grid)
			var about := _label(str(VOID_LOOK.FEATURE_ABOUT[now]), 17, Color(0.85, 0.85, 1.0))
			about.name = "Void about"
			_content.add_child(about)
			_content.add_child(_label("Glow colour", 20))
			_glow_swatches()
		"Name":
			_content.add_child(_label("Your name", 20))
			var edit := LineEdit.new()
			edit.name = "NameEdit"
			edit.max_length = 16
			edit.placeholder_text = "Type your name"
			edit.text = str(h.get("name", ""))
			edit.text_changed.connect(func(t: String) -> void: Game.hero["name"] = t)
			edit.text_submitted.connect(func(_t: String) -> void: close())
			_content.add_child(edit)
			_content.add_child(_label("Call me", 20))
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			for p in ["they", "she", "he"]:
				var label: String = {"they": "they / them", "she": "she / her", "he": "he / him"}[p]
				var b := _button(label, func() -> void: set_value("pronouns", p), "Pronoun " + p)
				b.toggle_mode = true
				b.button_pressed = str(h.get("pronouns", "they")) == p
				row.add_child(b)
			_content.add_child(row)
	_show_void()
	var first := _content.find_children("*", "Button", true, false)
	if not first.is_empty():
		(first[0] as Control).grab_focus.call_deferred()


func _arrows(what: String, value: String, on_step: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.add_child(_button("◀", on_step.bind(-1), "Button %s -1" % what))
	var l := _label("%s:  %s" % [what, value], 20)
	l.name = "Label " + what
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	row.add_child(_button("▶", on_step.bind(1), "Button %s 1" % what))
	_content.add_child(row)
	return row


func _slider(what: String, key: String, range_: Array, face := false) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var l := _label(what, 20)
	l.custom_minimum_size.x = 175
	row.add_child(l)
	var s := HSlider.new()
	s.name = "Slider " + key
	s.min_value = float(range_[0])
	s.max_value = float(range_[1])
	s.step = 0.05
	s.value = float(Game.hero.get(key, 1.0))
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.value_changed.connect(func(x: float) -> void:
		Game.hero[key] = x
		Game.equipment_changed.emit()
		if face:
			_face_label())
	row.add_child(s)
	_content.add_child(row)


func _face_label() -> void:
	# Moving a face slider can take the face off a ready-made one (or onto one): the label says which
	var l := _content.find_child("Label Face", true, false) as Label
	if l:
		var preset := FaceSculpt.preset_index(Game.hero)
		l.text = "Face:  " + (FaceSculpt.PRESETS[preset].name if preset >= 0 else "Your own")


func _swatches(part: String, only := []) -> void:
	# A grid of colours to click: the first is their own (as drawn), then the rest (or only these: skin tones)
	var grid := GridContainer.new()
	grid.name = "Swatches " + part
	grid.columns = 7
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	var pick := int(Game.hero.get("colors", {}).get(part, 0))
	var order: Array = range(Hero.SWATCHES.size() + 1) if only.is_empty() else [0] + only
	for k in order:
		var b := Button.new()
		b.name = "Swatch %d" % k
		b.custom_minimum_size = Vector2(54, 44)
		b.tooltip_text = "Their own" if k == 0 else ""
		b.text = "own" if k == 0 else ""
		var st := StyleBoxFlat.new()
		st.bg_color = Color(0.3, 0.25, 0.4) if k == 0 else Hero.SWATCHES[k - 1]
		st.set_corner_radius_all(8)
		if k == pick:
			st.border_color = Color(1, 1, 1)
			st.set_border_width_all(4)
		for state in ["normal", "hover", "pressed", "focus"]:
			var s2 := st.duplicate() as StyleBoxFlat
			if state in ["hover", "focus"]:
				s2.border_color = Color(1, 0.9, 0.5)
				s2.set_border_width_all(3 if k != pick else 5)
			b.add_theme_stylebox_override(state, s2)
		b.pressed.connect(set_color.bind(part, k))
		grid.add_child(b)
	_content.add_child(grid)


func _glow_swatches() -> void:
	# The Void glow colours (eyes, and the tips of their feature)
	var grid := GridContainer.new()
	grid.name = "Swatches glow"
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 6)
	var pick := posmod(int(Game.hero.get("void_glow", 0)), VOID_LOOK.GLOWS.size())
	for k in VOID_LOOK.GLOWS.size():
		var b := Button.new()
		b.name = "Glow %d" % k
		b.custom_minimum_size = Vector2(60, 44)
		b.tooltip_text = VOID_LOOK.GLOW_NAMES[k]
		var st := StyleBoxFlat.new()
		st.bg_color = VOID_LOOK.GLOWS[k]
		st.set_corner_radius_all(8)
		if k == pick:
			st.border_color = Color(1, 1, 1)
			st.set_border_width_all(4)
		for state in ["normal", "hover", "pressed", "focus"]:
			var s2 := st.duplicate() as StyleBoxFlat
			if state in ["hover", "focus"]:
				s2.border_color = Color(1, 0.9, 0.5)
				s2.set_border_width_all(3 if k != pick else 5)
			b.add_theme_stylebox_override(state, s2)
		b.pressed.connect(set_value.bind("void_glow", k))
		b.pressed.connect(func() -> void: Audio.play("ui_move", -8.0, 0.0))
		grid.add_child(b)
	_content.add_child(grid)


func _button(text: String, on_press: Callable, name := "") -> Button:
	var b := Button.new()
	b.text = text
	if name != "":
		b.name = name
	b.add_theme_font_size_override("font_size", 19)
	b.pressed.connect(on_press)
	b.pressed.connect(func() -> void: Audio.play("ui_move", -8.0, 0.0))
	return b


func _label(text: String, size: int, color := Color(1, 0.97, 0.9)) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l
