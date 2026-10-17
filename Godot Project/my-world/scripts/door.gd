extends Area3D

# A doorway: when the player walks in, load another scene and appear at a named spawn point there.

@export_file("*.tscn") var destination := ""
@export var spawn := ""
@export var place_name := ""          # shown if the destination isn't built yet
@export var closed_message := ""      # if set, the door is shut: show this instead (e.g. the portal outside the Shift)


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if not body is CharacterBody3D or destination == "":
		return
	if closed_message != "":
		Game.message(closed_message)
	else:
		Game.go(destination, spawn, place_name)
