extends Node3D

# A part of town that only appears once the story unlocks it, e.g. the cloud water slide at the end of the pilot.
# flag: an entry in Game.items (Game.give_item("cloud_slide") unlocks it; it's there from the next time the town loads).

@export var flag := ""


func _ready() -> void:
	if flag != "" and not Game.has_item(flag):
		queue_free()
