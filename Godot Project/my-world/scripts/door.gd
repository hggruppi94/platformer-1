extends Area3D

# A doorway: when the player walks in, load another scene and appear at a named spawn point there.

@export_file("*.tscn") var destination := ""
@export var spawn := ""
@export var place_name := ""          # shown if the destination isn't built yet


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D and destination != "":
		Game.go(destination, spawn, place_name)
