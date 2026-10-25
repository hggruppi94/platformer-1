extends Area3D

# The Skaters' Corner at a skate park (built by tools/build_town.gd and tools/build_skate_test.gd): stand in it and
# press Interact to swap who's skating, round everyone in scripts/rides.gd: Nina on her board, Dash on his BMX, Rex on
# his paw skates, and the rest. Each rides their own way (scenes/player/skate.gd, scenes/player/ride_kit.gd).
# Stepping off the ride makes you Nina again.

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
	_prompt.visible = _near
	if _near:
		var player := get_tree().get_first_node_in_group("player")
		var who: String = Rides.ride(player.rider).rider if player else "Nina"
		_prompt.text = "Skating: %s\nPress %s for the next skater" % [who, Settings.prompt("interact")]


func _unhandled_input(event: InputEvent) -> void:
	if not _near or get_tree().paused or Dialogue.is_active() or not event.is_action_pressed("interact"):
		return
	var player := get_tree().get_first_node_in_group("player")
	if player == null or not player.has_method("set_rider"):
		return
	get_viewport().set_input_as_handled()
	var i := Rides.ORDER.find(player.rider)
	var next: String = Rides.ORDER[(i + 1) % Rides.ORDER.size()]
	if not Game.has_item("skateboard"):
		Game.message("Pick up the skateboard first! It's in the middle of the Skate Park.")
		return
	player.set_rider(next)
	var r := Rides.ride(next)
	player.skate.hud.shout("%s: %s" % [r.rider, r.name], Color(1.0, 0.95, 0.6))
	Audio.play("ui_accept", -4.0, 0.0)
