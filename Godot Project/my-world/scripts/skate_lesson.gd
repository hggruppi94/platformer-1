extends CanvasLayer

# Autoload "SkateLesson": Coach Bruno's skate lesson (Nina's little brother took it over from Rook, who still helps:
# he cheers every step). It's offered the first time the player gets on a ride, and any time from the Lesson Pad at
# the Skate Park (scripts/lesson_pad.gd) or the pause menu. Step by step it teaches pushing, the ollie, a spin, a flip,
# a grab, a grind, a manual and then a combo (scenes/player/skate.gd, scenes/player/skate_tricks.gd), each step done
# for real before the next. Bruno says what to do in his own words (with his lisp: he lost a tooth), Rook woofs along,
# and a line under theirs says it plainly, with the player's own keys or controller buttons (Settings.fill); the
# Simple controls get their own lines. Bail twice on one step and the stress gets to Bruno: his Godfather voice comes
# out (a parody, our own lines), and then he's himself again.
#
# In the town Bruno and Rook stand by the Lesson Pad while it's on (their everyday selves step out of sight). Each
# step done is saved as a Dialogue flag ("skate_lesson_<step>"), so a lesson stopped halfway carries on from there;
# finishing pays REWARD sparkles once ("skate_lesson_done").

signal step_done(id: String)
signal finished

const REWARD := 10
const STEPS := [
	{"id": "push", "woof": "Woof!", "says": "Firtht thing: puth. Get thome thpeed up. Don't be thcared of it.", "text": "Push along: hold {move_forward}. Get some speed up!"},
	{"id": "ollie", "woof": "Woof woof!", "says": "Ollie time. Crouch... wait for it... POP.", "text": "Ollie: hold {jump} to crouch, then let go to pop. Hold it longer to go higher."},
	{"id": "spin", "woof": "Woof?", "says": "Now thpin it. A 180. Land backwardth if you have to. That'th thtill cool.", "text": "Spin: ollie, then hold {move_left} or {move_right} in the air. Land a 180!"},
	{"id": "flip", "woof": "Woof!", "says": "Flip trick! My favourite'th the Gap-Tooth Flip. Named after me. Obviouthly.", "text": "Flip trick: in the air, press {skate_flip}. Push a direction too for other flips.",
		"simple": "Flip trick: in the air, tap {skate_flip}. Push a direction too for other flips."},
	{"id": "grab", "woof": "Woof woof!", "says": "Grab your board in the air. Like it owetht you money. Then let go!", "text": "Grab: in the air, hold {skate_grab} to grab your board. Let go before you land!",
		"simple": "Grab: in the air, hold {skate_flip} to grab your board. Let go before you land!"},
	{"id": "grind", "woof": "Grrr-ind!", "says": "Rails! Thlide along it. Lean, don't panic. Rook panicth. Don't be Rook.",
		"text": "Grind: ollie up to a rail or the ledge and press {skate_grind}. Balance with {move_left} and {move_right}.",
		"simple": "Grind: ollie and come down on a rail or the ledge. You'll grind by yourself! Balance with {move_left} and {move_right}."},
	{"id": "manual", "woof": "Woof!", "says": "Manual: two wheelth, nice and balanthed. Like a waiter with a pizza.",
		"text": "Manual: rolling on the flat, tap {move_forward} then {move_back} quickly. Balance with {move_forward} and {move_back}.",
		"simple": "Manual: rolling on the flat, press {skate_grind}. Balance with {move_forward} and {move_back}."},
	{"id": "combo", "woof": "WOOF!", "says": "Latht one. Link three trickth before you land. Thith is where it getth good.",
		"text": "Combo: link three tricks before you land and roll away (a flip, a grab and a spin, or a grind into a manual). Popping a Gloop with {shoot} counts too!"},
]
const PRAISE := ["Thick! (Rook wags his whole back end.)", "YETH! (Rook does a proud little spin.)",
	"Nithe one. (Rook gives you a paw bump.)", "Okay that wath actually good. (Awoooo!)"]
# Under stress (two bails on one step): his Godfather voice, our own parody lines, then he's himself again
const STRESSED := [
	"(Bruno's voice goes low and slow and very Italian.) You come to MY thkate park... and you fall on MY ramp... (Normal again.) It'th fine. Again.",
	"(Very Italian.) Thith ramp... hath dithrethpected you. We will dithcuth thith with the ramp. (Normal.) Try again, you got it.",
	"(Deep voice.) I'm gonna make you an offer... a thnack break. Then you try again. (Normal.) Theriouthly, you're cloth.",
]
const COACH_SPOT := Vector3(1.6, 0.0, -1.0)   # where Bruno stands, from the Lesson Pad
const HELPER_SPOT := Vector3(2.6, 0.0, -0.2)  # and Rook beside him

var active := false
var _step := 0
var _skate: Node                     # the player's scenes/player/skate.gd while the lesson's on
var _coach: Node3D
var _helper: Node3D                  # Rook, cheering beside the coach
var _bails := 0                      # bails on this step, for when the stress gets to Bruno
var _stressed := ""
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
		Game.message("Any time! Bruno's at the Lesson Pad in the Skate Park, or pick Skate lesson in the pause menu.")


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
	_skate.bailed.connect(_on_bailed)
	_skate.tree_exiting.connect(stop)              # a scene change ends it (the steps done are kept)
	active = true
	_wait = 0.0
	_praise = ""
	_bails = 0
	_stressed = ""
	_pad = get_tree().current_scene.find_child("Lesson Pad", true, false) as Node3D
	if _pad:
		# Over to the Lesson Pad, if the player's far from it, and Bruno comes to coach (with Rook)
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
		_skate.bailed.disconnect(_on_bailed)
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


func _on_bailed() -> void:
	# Two bails on the same step and Bruno's Godfather voice comes out, once per step
	_bails += 1
	if _bails == 2 and _wait <= 0.0:
		_stressed = STRESSED[randi() % STRESSED.size()]
		if _coach:
			_coach_anim("tough")
		_show()


func _names(table: Dictionary) -> Array:
	var out := []
	for k in table:
		out.append(String(table[k][0]))
	return out


func complete(id: String) -> void:
	# A step done: Bruno and Rook are pleased, it's saved, and a moment later the next one
	if not active or step_id() != id or _wait > 0.0:
		return
	Dialogue.set_flag("skate_lesson_" + id)
	_step += 1
	_bails = 0
	_stressed = ""
	_praise = PRAISE[randi() % PRAISE.size()]
	_wait = 1.6
	Audio.play("ui_accept", -2.0, 0.0)
	for n in [_coach, _helper]:
		if n:
			var tw := (n as Node3D).create_tween()
			tw.tween_property(n, "position:y", (n as Node3D).position.y + 0.5, 0.15).set_trans(Tween.TRANS_QUAD)
			tw.tween_property(n, "position:y", (n as Node3D).position.y, 0.2).set_trans(Tween.TRANS_BOUNCE)
	if _coach:
		_coach_anim("idle")
	step_done.emit(id)
	_show()


func _finish() -> void:
	var first := not is_done()
	Dialogue.set_flag("skate_lesson_done")
	stop()
	if first:
		Game.add_sparkles(REWARD, "Skate lesson done! Bruno says you're a natural. Rook agrees. Woof!")
	else:
		Game.message("Skate lesson done again! Thick! Woof!")
	Game.save_game()
	finished.emit()


# -----------------------------------------------------------------------------
# Coach Bruno, and Rook helping
# -----------------------------------------------------------------------------
const COACH_ID := "bruno_alien"      # their everyday selves in town (routines), put away while they're coaching
const HELPER_ID := "rook"


func _add_coach(player: Node) -> void:
	_remove_coach()
	_coach = _stand("Coach Bruno", "Coach Bruno", String(Rides.ride("bruno").model), COACH_SPOT, player, 2.0)
	_helper = _stand("Helper Rook", "Rook", String(Rides.ride("rook").model), HELPER_SPOT, player, 1.6)
	if player.has_method("_show_npc"):
		for id in [COACH_ID, HELPER_ID]:
			player.call("_show_npc", id, false)       # no second Bruno or Rook wandering round town meanwhile


func _stand(node_name: String, tag_text: String, model_path: String, spot: Vector3, player: Node, tag_y: float) -> Node3D:
	var model := (load(model_path) as PackedScene).instantiate() as Node3D
	var n := Node3D.new()
	n.name = node_name
	n.add_child(model)
	get_tree().current_scene.add_child(n)
	n.global_position = _pad.global_position + _pad.global_basis * spot
	var look := (player as Node3D).global_position - n.global_position
	n.rotation.y = atan2(look.x, look.z)
	var anim := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim and anim.has_animation("idle"):
		anim.get_animation("idle").loop_mode = Animation.LOOP_LINEAR
		anim.play("idle")
	var tag := Label3D.new()
	tag.text = tag_text
	tag.font_size = 48
	tag.pixel_size = 0.006
	tag.outline_size = 10
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.modulate = Color(1.0, 0.9, 0.6)
	tag.position = Vector3(0, tag_y, 0)
	n.add_child(tag)
	return n


func _coach_anim(which: String) -> void:
	var anim := _coach.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim and anim.has_animation(which):
		anim.get_animation(which).loop_mode = Animation.LOOP_LINEAR
		anim.play(which, 0.2)


func _remove_coach() -> void:
	var had := false
	for n in [_coach, _helper]:
		if n and is_instance_valid(n):
			(n as Node).queue_free()
			had = true
	_coach = null
	_helper = null
	if had:
		var player := get_tree().get_first_node_in_group("player")
		if player and player.has_method("_show_npc"):
			if player.get("rider") != "rook":
				player.call("_show_npc", HELPER_ID, true)
			player.call("_show_npc", COACH_ID, true)


# -----------------------------------------------------------------------------
# On screen
# -----------------------------------------------------------------------------
func _show() -> void:
	if _praise != "":
		_title.text = "Coach Bruno (and Rook)"
		_woof.text = _praise
		_text.text = "Nice!" if _step < STEPS.size() else "That's the whole lesson!"
		return
	var s: Dictionary = STEPS[_step]
	_title.text = "Coach Bruno (and Rook)   ·   %d of %d" % [_step + 1, STEPS.size()]
	_woof.text = _stressed if _stressed != "" else "Bruno: %s\nRook: %s" % [String(s.says), String(s.woof)]
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
	_label(o, 20, Color(1.0, 0.85, 0.5)).text = "Bruno"
	_label(o, 22, Color(1, 0.97, 0.9)).text = "Yo! You thkate? I'm the coach round here. Want a leththon? Rook helpth.\n(Rook: Woof woof!)"
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
