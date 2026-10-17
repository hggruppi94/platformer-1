extends Area3D

# A bed (Nina's, in tools/build_interiors.gd). Stand next to it and press Interact to sleep: the screen fades out,
# the clock jumps to the next morning (Clock.WAKE_HOUR), HP/MP/SP fill up, the game saves, and the screen fades back in.

const FADE_TIME := 1.2
const HOLD_TIME := 1.6               # seconds of "Zzz..." on the dark screen

var _near := false
var _sleeping := false
@onready var _prompt: Label3D = $Prompt


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_prompt.visible = false


func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
		_near = true
		_prompt.text = "Press %s to sleep" % Settings.key_name("interact")
		_prompt.visible = not _sleeping


func _on_body_exited(body: Node3D) -> void:
	if body is CharacterBody3D:
		_near = false
		_prompt.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if _near and not _sleeping and event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		sleep()


func sleep() -> void:
	_sleeping = true
	_prompt.visible = false
	# A dark screen on top of everything; it keeps animating while the game is paused underneath
	var layer := CanvasLayer.new()
	layer.layer = 50
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	var dark := ColorRect.new()
	dark.color = Color(0.04, 0.02, 0.1)
	dark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dark.modulate.a = 0.0
	layer.add_child(dark)
	var text := Label.new()
	text.text = "Zzz..."
	text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text.add_theme_font_size_override("font_size", roundi(40 * Settings.text_scale))
	text.add_theme_color_override("font_color", Color(1, 0.95, 1))
	dark.add_child(text)
	get_tree().root.add_child(layer)
	get_tree().paused = true
	Audio.play("ui_back", -6.0)

	var tw := layer.create_tween()
	tw.tween_property(dark, "modulate:a", 1.0, FADE_TIME)
	tw.tween_callback(func() -> void:
		Clock.sleep_until_morning()
		Game.hp = Game.max_hp
		Game.mp = Game.max_mp
		Game.sp = Game.max_sp
		Game.stats_changed.emit()
		Game.sp_changed.emit()
		Game.save_game()
		text.text = "Zzz...\n\nGood morning!\nDay %d, %s" % [Clock.day, Clock.time_string()])
	tw.tween_interval(HOLD_TIME)
	tw.tween_property(dark, "modulate:a", 0.0, FADE_TIME)
	tw.tween_callback(func() -> void:
		get_tree().paused = false
		layer.queue_free()
		_sleeping = false
		_prompt.visible = _near
		Game.message("Good morning! It's day %d. You feel well rested." % Clock.day))
