extends Area3D

# A talk spot: put one under a character (scenes/town/characters.tscn) to make them someone Nina can talk to.
# When she's close, their name shows over their head (only then), and the nearest one says "Press F to talk".
# What they say is in res://dialogue/<character_id>.json (scripts/dialogue.gd plays it).
# While they talk, they turn to face her and stop where they are; afterwards their routine (scripts/routine.gd) or
# their own wandering (scripts/wanderer.gd) carries on.

@export var character_id := ""
@export var display_name := ""
@export var talk_radius := 2.6
@export var name_height := 2.0                     # metres above the character's feet
@export var turns := true                          # face Nina while talking (not for a voice behind a window)

var _name_label: Label3D
var _prompt: Label3D
var _player: Node3D
var _talking := false
var _home_yaw := 0.0
var _body: Node3D                                   # the character this belongs to


func _ready() -> void:
	_body = get_parent() as Node3D
	_home_yaw = _body.rotation.y
	monitorable = false
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = talk_radius
	shape.shape = sphere
	shape.position.y = 1.0
	add_child(shape)
	_name_label = _label(display_name, 26, Color(1, 1, 1))
	_name_label.position.y = name_height
	_prompt = _label("", 20, Color(1, 0.95, 0.7))
	_prompt.position.y = name_height - 0.22
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	Quests.changed.connect(func(_q: String) -> void: _name_label.text = Quests.display_name(character_id, display_name))
	_show(false)
	set_prompt(false)


func _exit_tree() -> void:
	Dialogue.exit_range(self)


func _label(text: String, size: int, color: Color) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.01
	l.outline_size = 10
	l.modulate = color
	l.outline_modulate = Color(0.15, 0.08, 0.2)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.top_level = false
	add_child(l)
	return l


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		_player = body
		_show(true)
		Dialogue.enter_range(self)


func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		_show(false)
		set_prompt(false)
		Dialogue.exit_range(self)


func _show(on: bool) -> void:
	_name_label.text = Quests.display_name(character_id, display_name)     # e.g. "Future Mayor Rex", after his quest
	_name_label.visible = on


func set_prompt(on: bool) -> void:
	# Called by the Dialogue autoload: only the nearest talk spot shows it
	_prompt.text = "Press %s to talk" % Settings.key_name("interact")
	_prompt.visible = on


func begin_talk() -> void:
	_talking = true
	if "talking" in _body:
		_body.set("talking", true)


func end_talk() -> void:
	_talking = false
	if "talking" in _body:
		_body.set("talking", false)


func _process(delta: float) -> void:
	# Face Nina while talking (models face +Z, so the yaw that faces a point is atan2(dx, dz)). Without a routine or
	# wandering of their own, turn back to how they stood afterwards.
	if not turns:
		return
	var target := _home_yaw
	if _talking and _player and is_instance_valid(_player):
		var to := _player.global_position - _body.global_position
		target = atan2(to.x, to.z) - (_body.get_parent() as Node3D).global_rotation.y
	elif _body is CharacterBody3D or _body.has_node("Routine"):
		return
	_body.rotation.y = lerp_angle(_body.rotation.y, target, minf(1.0, 6.0 * delta))
