extends Area3D

# Sits just above an escalator's steps and carries anyone standing on them.

@export var carry := Vector3.ZERO        # world-space velocity along the steps (m/s)


func _physics_process(delta: float) -> void:
	for body in get_overlapping_bodies():
		if body is CharacterBody3D and body.is_on_floor():
			body.global_position += carry * delta
