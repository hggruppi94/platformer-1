extends Area3D

# A quest spot: somewhere in town Nina can do something for a quest, like hang a VOTE REX poster on a signpost.
# While the quest is on the right step (scripts/quests.gd), walking up to it shows "Press F to hang a poster", and
# Interact sets its flag, which is what the quest step waits for. Its "Done" child (the poster) shows once the flag
# is set, for good. tools/build_town.gd puts these in the town.

@export var quest := ""
@export var step := ""                             # the step this spot is for
@export var flag := ""                             # set when she uses it
@export var action := "hang a poster"              # "Press F to <action>"
@export var done_message := ""
@export var radius := 2.4

var _prompt: Label3D
var _inside := false
var _offered := false
var _done_node: Node3D


func _ready() -> void:
	monitorable = false
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	shape.shape = sphere
	shape.position.y = 1.0
	add_child(shape)
	_prompt = Label3D.new()
	_prompt.font_size = 20
	_prompt.pixel_size = 0.01
	_prompt.outline_size = 10
	_prompt.modulate = Color(1, 0.95, 0.7)
	_prompt.outline_modulate = Color(0.15, 0.08, 0.2)
	_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt.no_depth_test = true
	_prompt.position.y = 2.4
	add_child(_prompt)
	_done_node = get_node_or_null("Done") as Node3D
	body_entered.connect(func(b: Node3D) -> void:
		if b.is_in_group("player"):
			_inside = true)
	body_exited.connect(func(b: Node3D) -> void:
		if b.is_in_group("player"):
			_inside = false)
	set_prompt(false)


func _exit_tree() -> void:
	Dialogue.exit_range(self)


func is_open() -> bool:
	# Can she use it right now?
	return Quests.is_ready(quest, step) and not Dialogue.flags.has(flag)


func _process(_delta: float) -> void:
	if _done_node:
		_done_node.visible = Dialogue.flags.has(flag)
	var offer := _inside and is_open()
	if offer != _offered:
		_offered = offer
		if offer:
			Dialogue.enter_range(self)               # the nearest spot gets the prompt, same as people
		else:
			Dialogue.exit_range(self)
			set_prompt(false)


func set_prompt(on: bool) -> void:
	_prompt.text = "Press %s to %s" % [Settings.key_name("interact"), action]
	_prompt.visible = on


func use() -> void:
	# Called by Dialogue when she presses Interact here
	if not is_open():
		return
	Audio.play("pickup", -4.0)
	if done_message != "":
		Game.message(done_message)
	Dialogue.set_flag(flag)
	Game.save_game()
