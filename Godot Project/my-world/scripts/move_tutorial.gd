extends CanvasLayer

# The movement tutorial at the start of a new game (Hayden's 12 Nov 2026 playtest: "maybe a movement tutorial", and
# "way less popups"). It replaces the four how-to tips that used to pop up one after another once the hero was made.
#
# One calm card at the top of the screen, like a coach beside you: one thing to try at a time, in the hero's own
# house, while Nina waits outside. Doing it ticks it off with a little chime and the next one slides in. A row of dots
# shows how far along you are. Nothing is held: you can walk out of the door at any point, and the last step is
# "go outside" anyway, so a player who already knows how to move just walks out and it's over.
#
#   look    move the mouse / right stick           (the camera turns a little way)
#   walk    {moves}                                (a few metres walked)
#   jump    {jump}
#   double  {jump} again in the air                (a double jump)
#   roll    {dash}                                 (a roll)
#   sprint  hold {dash}                            (sprinting for a moment)
#   door    out of the front door to see who's knocking
#
# Settings > tips off skips straight to the door step. Saved as Dialogue flags ("tut_<step>", "tut_done"), so a load
# carries on where it was. No class_name on purpose (preload it), so --script tools can load it before the autoloads.

signal finished

const STEPS := [
	{"id": "look", "text": "Move the mouse to look!", "pad": "Right stick to look!"},
	{"id": "walk", "text": "{moves} to walk!"},
	{"id": "jump", "text": "{jump} to jump!"},
	{"id": "double", "text": "{jump} again in the air!"},
	{"id": "roll", "text": "{dash} to roll!"},
	{"id": "sprint", "text": "Hold {dash} to run fast!"},
	{"id": "door", "text": "Now open the door!"},
]
const LOOK_TURN := 1.2               # radians of camera turn that count as having looked round
const WALK_METRES := 4.0
const SPRINT_FOR := 0.4
const DONE_FLAG := "tut_done"

var player: Node3D
var home: Node3D                     # the hero's house ("My Home"): leaving it ends the tutorial
var _i := -1
var _turned := 0.0
var _last_yaw := 0.0
var _walked := 0.0
var _last_pos := Vector3.ZERO
var _sprint_t := 0.0
var _tick := 0.0                     # the "ticked!" moment between one step and the next
var _panel: PanelContainer
var _text: Label
var _dots: HBoxContainer
var _check: Label


func _ready() -> void:
	layer = 44
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_build()
	visible = false


func running() -> bool:
	return _i >= 0


func step_id() -> String:
	return str(STEPS[_i].id) if running() else ""


func start(p: Node3D, house: Node3D) -> void:
	player = p
	home = house
	if Dialogue.flags.has(DONE_FLAG) or player == null:
		return
	_i = 0
	if not Settings.tips:
		_i = STEPS.size() - 1                    # tips off: they know what they're doing, just point at the door
	while _i < STEPS.size() - 1 and Dialogue.flags.has("tut_" + str(STEPS[_i].id)):
		_i += 1
	_begin_step()
	visible = true


func stop() -> void:
	_i = -1
	visible = false


func _begin_step() -> void:
	_turned = 0.0
	_walked = 0.0
	_sprint_t = 0.0
	_tick = 0.0
	_last_pos = player.global_position
	var arm := player.get("spring_arm") as Node3D
	_last_yaw = arm.rotation.y if arm else 0.0
	_check.visible = false
	_fill()
	_panel.modulate.a = 0.0
	create_tween().tween_property(_panel, "modulate:a", 1.0, 0.3)


func _fill() -> void:
	var s: Dictionary = STEPS[_i]
	var t := str(s.get("pad", s.text)) if Settings.last_device == "pad" else str(s.text)
	_text.text = Settings.fill(t)
	for c in _dots.get_children():
		var k: int = c.get_index()
		(c as Label).text = "●" if k < _i else ("◉" if k == _i else "○")
		(c as Label).add_theme_color_override("font_color", UiStyle.TEAL if k < _i else (UiStyle.GOLD if k == _i else Color(0.7, 0.65, 0.85)))


func _process(delta: float) -> void:
	if not running():
		return
	if not is_instance_valid(player):
		stop()
		return
	# Out of sight while a talk, a cutscene or a menu is up (it carries on after)
	var busy := Dialogue.is_active() or not get_tree().get_nodes_in_group("cutscene_playing").is_empty() \
		or Creator.is_open() or PlayerMenu.is_open()
	_panel.visible = not busy
	if busy:
		return
	_fill()                                       # (follows the keyboard or the pad the moment they switch)
	if _tick > 0.0:
		_tick -= delta
		if _tick <= 0.0:
			_i += 1
			_begin_step()
		return
	if outside():
		# Out of the door: whatever's left doesn't matter any more
		for s in STEPS:
			Dialogue.set_flag("tut_" + str(s.id))
		Dialogue.set_flag(DONE_FLAG)
		Audio.play("pickup", -6.0, 0.0)
		stop()
		finished.emit()
		return
	if _done_now(delta):
		Dialogue.set_flag("tut_" + step_id())
		_check.visible = true
		Audio.play("pickup", -8.0, 0.1)
		_tick = 0.7


func _done_now(delta: float) -> bool:
	var locked := bool(player.get("input_locked"))
	match step_id():
		"look":
			var arm := player.get("spring_arm") as Node3D
			if arm:
				_turned += absf(angle_difference(_last_yaw, arm.rotation.y))
				_last_yaw = arm.rotation.y
			return _turned >= LOOK_TURN
		"walk":
			var flat := (player.global_position - _last_pos) * Vector3(1, 0, 1)
			_last_pos = player.global_position
			if flat.length() < 1.0:                   # (not a teleport)
				_walked += flat.length()
			return _walked >= WALK_METRES
		"jump":
			return Input.is_action_just_pressed("jump") and not locked
		"double":
			return bool(player.get("_air_jump_used"))
		"roll":
			return player.has_method("is_rolling") and player.is_rolling()
		"sprint":
			_sprint_t = (_sprint_t + delta) if bool(player.get("sprinting")) else 0.0
			return _sprint_t >= SPRINT_FOR
	return false


func outside() -> bool:
	# Past the front wall of the house (its +Z is the front, where the doorway is: tools/build_earth.gd _my_home)
	if home == null or not is_instance_valid(home) or not home.is_inside_tree() \
			or not is_instance_valid(player) or not player.is_inside_tree():
		return false                              # (mid scene change: the house or the hero has left the tree)
	var local := home.global_transform.affine_inverse() * player.global_position
	return local.z > 5.0 or absf(local.x) > 5.5 or local.z < -5.0


func _build() -> void:
	_panel = PanelContainer.new()
	_panel.name = "Tutorial"
	# Top middle, under the clock: clear of the hero, and of messages at the bottom
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.offset_top = 78
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.07, 0.18, 0.82)
	style.border_color = UiStyle.TEAL
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(14)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	_panel.add_child(v)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	_text = Label.new()
	_text.add_theme_font_override("font", Dialogue.font)
	_text.add_theme_font_size_override("font_size", Settings.hud(24))
	_text.add_theme_color_override("font_color", UiStyle.TEXT)
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size.x = Settings.hud(520)
	row.add_child(_text)
	_check = Label.new()
	_check.text = "✔"
	_check.add_theme_font_size_override("font_size", Settings.hud(28))
	_check.add_theme_color_override("font_color", UiStyle.TEAL)
	row.add_child(_check)
	_dots = HBoxContainer.new()
	_dots.alignment = BoxContainer.ALIGNMENT_CENTER
	_dots.add_theme_constant_override("separation", 8)
	v.add_child(_dots)
	for i in STEPS.size():
		var d := Label.new()
		d.add_theme_font_size_override("font_size", Settings.hud(16))
		_dots.add_child(d)
