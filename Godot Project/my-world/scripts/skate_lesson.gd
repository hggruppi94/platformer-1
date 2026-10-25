extends CanvasLayer

# Autoload "SkateLesson": Coach Rook's skate lesson. It's offered the first time the player gets on a ride, and any
# time from the Lesson Pad at the Skate Park (scripts/lesson_pad.gd) or the pause menu. Step by step it teaches
# pushing, the ollie, a spin, a flip, a grab, a grind, a manual and then a combo (scenes/player/skate.gd,
# scenes/player/skate_tricks.gd), each step done for real before the next. Rook doesn't say much ("Woof!"), so a line
# under his says what he's showing, with the player's own keys or controller buttons (Settings.fill), and the
# Simple controls get their own lines.
#
# In the town Rook stands by the Lesson Pad while it's on (his everyday self steps out of sight). Each step done is
# saved as a Dialogue flag ("skate_lesson_<step>"), so a lesson stopped halfway carries on from there; finishing pays
# REWARD sparkles once ("skate_lesson_done").

signal step_done(id: String)
signal finished

const REWARD := 10
const STEPS := [
	{"id": "push", "woof": "Woof!", "text": "Push along: hold {move_forward}. Get some speed up!"},
	{"id": "ollie", "woof": "Woof woof!", "text": "Ollie: hold {jump} to crouch, then let go to pop. Hold it longer to go higher."},
	{"id": "spin", "woof": "Woof?", "text": "Spin: ollie, then hold {move_left} or {move_right} in the air. Land a 180!"},
	{"id": "flip", "woof": "Woof!", "text": "Flip trick: in the air, press {skate_flip}. Push a direction too for other flips.",
		"simple": "Flip trick: in the air, tap {skate_flip}. Push a direction too for other flips."},
	{"id": "grab", "woof": "Woof woof!", "text": "Grab: in the air, hold {skate_grab} to grab your board. Let go before you land!",
		"simple": "Grab: in the air, hold {skate_flip} to grab your board. Let go before you land!"},
	{"id": "grind", "woof": "Grrr-ind!",
		"text": "Grind: ollie up to a rail or the ledge and press {skate_grind}. Balance with {move_left} and {move_right}.",
		"simple": "Grind: ollie and come down on a rail or the ledge. You'll grind by yourself! Balance with {move_left} and {move_right}."},
	{"id": "manual", "woof": "Woof!",
		"text": "Manual: rolling on the flat, tap {move_forward} then {move_back} quickly. Balance with {move_forward} and {move_back}.",
		"simple": "Manual: rolling on the flat, press {skate_grind}. Balance with {move_forward} and {move_back}."},
	{"id": "combo", "woof": "WOOF!", "text": "Combo: link three tricks before you land and roll away (a flip, a grab and a spin, or a grind into a manual)."},
]
const PRAISE := ["WOOF! (Rook wags his whole back end.)", "Woof woof! (A proud little spin.)",
	"Woof! (Rook gives you a paw bump.)", "Awoooo! (That's a good one.)"]
const COACH_SPOT := Vector3(1.6, 0.0, -1.0)   # where Rook stands, from the Lesson Pad

var active := false
var _step := 0
var _skate: Node                     # the player's scenes/player/skate.gd while the lesson's on
var _coach: Node3D
var _pad: Node3D
var _wait := 0.0                     # a moment of praise between one step and the next
var _praise := ""
var _layer_ui: PanelContainer
var _title: Label
var _woof: Label
var _text: Label
var _offer: PanelContainer
var _offer_yes: Button


func _ready() -> void:
	layer = 44
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()


func is_done() -> bool:
	return Dialogue.flags.has("skate_lesson_done")


func step_id() -> String:
	return STEPS[_step].id if _step < STEPS.size() else ""


# -----------------------------------------------------------------------------
# Offering it, starting and stopping
# -----------------------------------------------------------------------------
func offer(force := false) -> void:
	# The first time the player gets on a ride (scenes/player/skate.gd). Not in tests and screenshot tools, which run
	# their own main loop, unless they ask for it.
	if not force and (get_tree().get_script() != null or Dialogue.flags.has("skate_lesson_offered") or is_done()):
		return
	if active or _offer.visible:
		return
	Dialogue.set_flag("skate_lesson_offered")
	_offer.visible = true
	_lock(true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_offer_yes.grab_focus.call_deferred()


func answer(yes: bool) -> void:
	if not _offer.visible:
		return
	_offer.visible = false
	_lock(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if yes:
		start()
	else:
		Game.message("Any time! Rook's at the Lesson Pad in the Skate Park, or pick Skate lesson in the pause menu.")


func is_offering() -> bool:
	return _offer.visible


func start() -> bool:
	var player := get_tree().get_first_node_in_group("player")
	if player == null or player.get("skate") == null:
		return false
	if not Game.has_item("skateboard"):
		Game.message("Pick up the skateboard first! It's in the middle of the Skate Park.")
		return false
	if active:
		return true
	if is_done() and _first_undone() >= STEPS.size():
		for s in STEPS:                              # a lesson again, from the top (the reward was paid already)
			Dialogue.flags.erase("skate_lesson_" + s.id)
	_step = _first_undone()
	if not Game.riding:
		Game.toggle_skateboard()
	_skate = player.skate
	_skate.popped.connect(_on_popped)
	_skate.tricks.added.connect(_on_added)
	_skate.tricks.banked.connect(_on_banked)
	_skate.tree_exiting.connect(stop)              # a scene change ends it (the steps done are kept)
	active = true
	_wait = 0.0
	_praise = ""
	_pad = get_tree().current_scene.find_child("Lesson Pad", true, false) as Node3D
	if _pad:
		# Over to the Lesson Pad, if the player's far from it, and Rook comes to coach
		if (player as Node3D).global_position.distance_to(_pad.global_position) > 30.0:
			(player as Node3D).global_position = _pad.global_position + Vector3(0, 1.0, -2.0)
			player.velocity = Vector3.ZERO
		_add_coach(player)
	_layer_ui.visible = true
	Audio.play("ui_accept", -4.0, 0.0)
	return true


func stop() -> void:
	if not active:
		return
	active = false
	_layer_ui.visible = false
	if _skate and is_instance_valid(_skate):
		_skate.popped.disconnect(_on_popped)
		_skate.tricks.added.disconnect(_on_added)
		_skate.tricks.banked.disconnect(_on_banked)
		_skate.tree_exiting.disconnect(stop)
	_skate = null
	_remove_coach()


func _first_undone() -> int:
	for i in STEPS.size():
		if not Dialogue.flags.has("skate_lesson_" + STEPS[i].id):
			return i
	return STEPS.size()


# -----------------------------------------------------------------------------
# Watching the player skate
# -----------------------------------------------------------------------------
func _process(delta: float) -> void:
	if not active:
		return
	if _wait > 0.0:
		_wait -= delta
		if _wait <= 0.0:
			_praise = ""
			if _step >= STEPS.size():
				_finish()
				return
	elif step_id() == "push" and Game.riding and Vector2(_skate.p.velocity.x, _skate.p.velocity.z).length() > 6.0:
		complete("push")
	_show()


func _on_popped() -> void:
	if step_id() == "ollie":
		complete("ollie")


func _on_added(name: String) -> void:
	var t: Dictionary = _skate.ride.tricks
	match step_id():
		"spin":
			if name.is_valid_int():                  # spins go in as "180", "360"...
				complete("spin")
		"flip":
			if _names(t.flips).has(name) or name == String(t.special[0]):
				complete("flip")
		"grab":
			if _names(t.grabs).has(name):
				complete("grab")
		"grind":
			if _names(t.grinds).has(name):
				complete("grind")
		"manual":
			if name == String(t.manual) or name == String(t.nose_manual):
				complete("manual")


func _on_banked(_points: int, names: String) -> void:
	if step_id() == "combo" and names.split(" + ").size() >= 3:
		complete("combo")


func _names(table: Dictionary) -> Array:
	var out := []
	for k in table:
		out.append(String(table[k][0]))
	return out


func complete(id: String) -> void:
	# A step done: Rook's pleased, it's saved, and a moment later the next one
	if not active or step_id() != id or _wait > 0.0:
		return
	Dialogue.set_flag("skate_lesson_" + id)
	_step += 1
	_praise = PRAISE[randi() % PRAISE.size()]
	_wait = 1.6
	Audio.play("ui_accept", -2.0, 0.0)
	if _coach:
		var tw := _coach.create_tween()
		tw.tween_property(_coach, "position:y", _coach.position.y + 0.5, 0.15).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(_coach, "position:y", _coach.position.y, 0.2).set_trans(Tween.TRANS_BOUNCE)
	step_done.emit(id)
	_show()


func _finish() -> void:
	var first := not is_done()
	Dialogue.set_flag("skate_lesson_done")
	stop()
	if first:
		Game.add_sparkles(REWARD, "Skate lesson done! Rook's proud of you.")
	else:
		Game.message("Skate lesson done again! Woof!")
	Game.save_game()
	finished.emit()


# -----------------------------------------------------------------------------
# Coach Rook
# -----------------------------------------------------------------------------
func _add_coach(player: Node) -> void:
	_remove_coach()
	var model := (load(String(Rides.ride("rook").model)) as PackedScene).instantiate() as Node3D
	_coach = Node3D.new()
	_coach.name = "Coach Rook"
	_coach.add_child(model)
	get_tree().current_scene.add_child(_coach)
	_coach.global_position = _pad.global_position + _pad.global_basis * COACH_SPOT
	var look := (player as Node3D).global_position - _coach.global_position
	_coach.rotation.y = atan2(look.x, look.z)
	var anim := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim and anim.has_animation("idle"):
		anim.get_animation("idle").loop_mode = Animation.LOOP_LINEAR
		anim.play("idle")
	var tag := Label3D.new()
	tag.text = "Coach Rook"
	tag.font_size = 48
	tag.pixel_size = 0.006
	tag.outline_size = 10
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.modulate = Color(1.0, 0.9, 0.6)
	tag.position = Vector3(0, 2.1, 0)
	_coach.add_child(tag)
	if player.has_method("_show_npc"):
		player.call("_show_npc", "rook", false)       # no second Rook wandering round town meanwhile


func _remove_coach() -> void:
	if _coach and is_instance_valid(_coach):
		_coach.queue_free()
		var player := get_tree().get_first_node_in_group("player")
		if player and player.has_method("_show_npc") and player.get("rider") != "rook":
			player.call("_show_npc", "rook", true)
	_coach = null


# -----------------------------------------------------------------------------
# On screen
# -----------------------------------------------------------------------------
func _show() -> void:
	if _praise != "":
		_title.text = "Coach Rook"
		_woof.text = _praise
		_text.text = "Nice!" if _step < STEPS.size() else "That's the whole lesson!"
		return
	var s: Dictionary = STEPS[_step]
	_title.text = "Coach Rook   ·   %d of %d" % [_step + 1, STEPS.size()]
	_woof.text = String(s.woof)
	var line := String(s.get("simple", s.text)) if Skate.simple() else String(s.text)
	if not Game.riding:
		line = "Hop on your ride first: {toggle_skateboard}."
	_text.text = Settings.fill(line)


func _lock(on: bool) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player and "input_locked" in player:
		player.set("input_locked", on)


func _build() -> void:
	_layer_ui = _box(Control.PRESET_TOP_RIGHT)
	_layer_ui.name = "Lesson"
	_layer_ui.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_layer_ui.offset_right = -16
	_layer_ui.offset_top = 150
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	_layer_ui.add_child(v)
	_title = _label(v, 18, Color(1.0, 0.85, 0.5))
	_woof = _label(v, 22, Color(0.75, 0.9, 1.0))
	_text = _label(v, 20, Color(1, 0.97, 0.9))
	var stop_hint := _label(v, 15, Color(0.8, 0.8, 0.9))
	stop_hint.text = "(Stop the lesson any time from the pause menu)"
	# The offer, the first time on a ride
	_offer = _box(Control.PRESET_CENTER)
	_offer.name = "Offer"
	_offer.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_offer.grow_vertical = Control.GROW_DIRECTION_BOTH
	var o := VBoxContainer.new()
	o.add_theme_constant_override("separation", 12)
	_offer.add_child(o)
	_label(o, 20, Color(1.0, 0.85, 0.5)).text = "Rook"
	_label(o, 22, Color(1, 0.97, 0.9)).text = "Woof! Woof woof?\n(Rook rolls up on his paw skates. He's offering you a skate lesson!)"
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	o.add_child(row)
	_offer_yes = Button.new()
	_offer_yes.name = "Yes"
	_offer_yes.text = "Yes please!"
	_offer_yes.pressed.connect(answer.bind(true))
	row.add_child(_offer_yes)
	var no := Button.new()
	no.name = "No"
	no.text = "Not now"
	no.pressed.connect(answer.bind(false))
	row.add_child(no)
	for b in [_offer_yes, no]:
		(b as Button).add_theme_font_size_override("font_size", 20)
		(b as Button).custom_minimum_size = Vector2(170, 44)


func _box(preset: int) -> PanelContainer:
	var p := PanelContainer.new()
	p.visible = false
	p.set_anchors_and_offsets_preset(preset)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.07, 0.18, 0.9)
	style.border_color = Color(0.75, 0.9, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(14)
	p.add_theme_stylebox_override("panel", style)
	add_child(p)
	return p


func _label(parent: Node, size: int, color: Color) -> Label:
	var l := Label.new()
	l.custom_minimum_size.x = 400
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l
