extends Area3D

# The Lesson Pad at the Skate Park (built by tools/skate_kit.gd lesson_pad): stand on it and press Interact for Coach
# Rook's skate lesson (scripts/skate_lesson.gd). It carries on from the last step done, or starts again once it's all
# been learned.

var _near := false
var _prompt: Label3D


func _ready() -> void:
	body_entered.connect(func(b: Node3D) -> void: if b.is_in_group("player"): _near = true)
	body_exited.connect(func(b: Node3D) -> void: if b.is_in_group("player"): _near = false)
	_prompt = Label3D.new()
	_prompt.name = "Prompt"
	_prompt.font_size = 48
	_prompt.pixel_size = 0.006
	_prompt.outline_size = 10
	_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt.position = Vector3(0, 2.3, 0)        # above the pad's sign
	_prompt.visible = false
	add_child(_prompt)


func _process(_delta: float) -> void:
	_prompt.visible = _near and not SkateLesson.active
	if _prompt.visible:
		var what := "the skate lesson again" if SkateLesson.is_done() else "a skate lesson with Rook"
		_prompt.text = "Press %s for %s" % [Settings.prompt("interact"), what]


func _unhandled_input(event: InputEvent) -> void:
	if not _near or SkateLesson.active or get_tree().paused or Dialogue.is_active() or not event.is_action_pressed("interact"):
		return
	get_viewport().set_input_as_handled()
	SkateLesson.start()
