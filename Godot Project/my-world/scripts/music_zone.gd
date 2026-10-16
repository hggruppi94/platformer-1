extends Area3D

# While Nina is inside this area, its track plays instead of the scene's music (e.g. "behind_walls").

@export var track := ""


func _ready() -> void:
	body_entered.connect(func(b): if b is Player: Audio.push_zone(track))
	body_exited.connect(func(b): if b is Player: Audio.pop_zone(track))
