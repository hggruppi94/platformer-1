extends Node3D

# The Old Taproot's ears, in effect (scripts/garden_caves.gd): it's in Pip's glow's "glow_wake" group, so the first
# time the glow reaches him he wakes up and opens his eyes.

var caves: Node
var awake := false


func _ready() -> void:
	add_to_group("glow_wake")


func glow_wake() -> void:
	if awake:
		return
	awake = true
	if caves:
		caves.call("wake_taproot")
