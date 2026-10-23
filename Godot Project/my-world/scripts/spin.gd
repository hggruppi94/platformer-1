extends Node3D

# Turns slowly round and round (the dance studio's disco ball). Gentler with reduce motion on.

@export var speed := 0.8                         # radians a second


func _process(delta: float) -> void:
	rotation.y += speed * delta * (0.3 if Settings.reduce_motion else 1.0)
