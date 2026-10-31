extends Area3D

# A doorway: when the player walks in, load another scene and appear at a named spawn point there.

@export_file("*.tscn") var destination := ""
@export var spawn := ""
@export var place_name := ""          # shown if the destination isn't built yet
@export var closed_message := ""      # if set, the door is shut: show this instead (e.g. the portal outside the Shift)


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	# Only Nina: Rex, Rook and the Gloops are CharacterBody3Ds too, and used to take the whole game inside
	if not body.is_in_group("player") or destination == "":
		return
	if closed_message != "":
		Game.message(closed_message)
	else:
		if "ortal" in spawn or "ortal" in str(get_parent().name):
			# Through the portal: a whoosh and a wobble (scripts/juice.gd)
			Juice.blip("whoosh", 0.8, -4.0)
			Juice.shake(0.3)
			Juice.rumble(0.4, 0.3, 0.3)
		else:
			Juice.rumble(0.1, 0.05)
		Game.go(destination, spawn, place_name)
