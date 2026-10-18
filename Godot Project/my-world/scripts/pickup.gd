extends Area3D

# An item lying in the world: spins and bobs, and gives the player the item when touched.
# item: "skateboard" (more later). Disappears for good once the player owns the item.

@export var item := "skateboard"

var t := 0.0
@onready var visual: Node3D = get_child(1) if get_child_count() > 1 else null


func _ready() -> void:
	if Game.has_item(item):
		queue_free()
		return
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	t += delta
	if visual:
		visual.rotation.y = t * 1.5
		visual.position.y = 0.6 + sin(t * 2.0) * 0.12


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		Game.give_item(item)
		queue_free()
