extends Area3D

# The Mothership Pad (built by tools/build_town.gd, near the foot of the Observatory's hill). Stand on it and press
# Interact: the mothership (scripts/mothership.gd) leaves its loop, comes down to hover over the pad and beams Nina up
# to fly it. The pad's rings glow brighter while it's on its way.

@export var ground_offset := 1.0                    # this area sits this far above the pad's surface

var _near := false
var _rings: Array[StandardMaterial3D] = []
var _t := 0.0
@onready var _prompt: Label3D = $Prompt


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_prompt.visible = false
	for n in get_parent().find_children("Pad Ring*", "MeshInstance3D", false, false):
		var mi := n as MeshInstance3D
		var m := (mi.material_override as StandardMaterial3D).duplicate() as StandardMaterial3D
		mi.material_override = m
		_rings.append(m)


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		_near = true
		_refresh_prompt()


func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		_near = false
		_prompt.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if _near and not get_tree().paused and event.is_action_pressed("interact") and not Dialogue.is_active():
		var ship := _ship()
		if ship == null:
			return
		get_viewport().set_input_as_handled()
		if ship.summon(pad_spot()):
			Audio.play("beam", -6.0)
			Game.message("The mothership is on its way! Stay on the pad.")
		_refresh_prompt()


func pad_spot() -> Vector3:
	return global_position - Vector3(0, ground_offset, 0)


func _ship() -> Node:
	return get_tree().get_first_node_in_group("mothership")


func _refresh_prompt() -> void:
	var ship := _ship()
	var player := get_tree().get_first_node_in_group("player")
	_prompt.visible = _near and ship != null and not (player and player.get("carried"))
	if ship and ship.is_coming():
		_prompt.text = "The mothership is coming!"
	else:
		_prompt.text = "Press %s to call the mothership" % Settings.key_name("interact")


func _process(delta: float) -> void:
	_t += delta
	if _near:
		_refresh_prompt()
	# The rings pulse gently, and faster and brighter while the ship is on its way
	var ship := _ship()
	var coming: bool = ship != null and ship.is_coming()
	var speed := 1.2 if Settings.reduce_flashing else (6.0 if coming else 2.0)
	for i in _rings.size():
		var wave := 0.5 + 0.5 * sin(_t * speed - i * 1.2)
		_rings[i].emission_energy_multiplier = lerpf(0.6, 2.6 if coming else 1.6, wave)
