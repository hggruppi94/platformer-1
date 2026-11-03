extends Area3D

# A safety net far below a place: if the player ever drops out of the world (over a wall, through a gap nobody
# spotted), this catches them and puts them gently back at a safe spot instead of letting them fall forever.

@export var back_to := NodePath()        # a Marker3D (or any Node3D) to put them back at
@export var message := "Whoops! Back you go."


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	# Only the player: anyone else who falls (a Gloop knocked off) just keeps falling out of the way
	if not body.is_in_group("player"):
		return
	var spot := get_node_or_null(back_to) as Node3D
	if spot == null:
		return
	body.global_position = spot.global_position
	if body is CharacterBody3D:
		(body as CharacterBody3D).velocity = Vector3.ZERO
	if message != "":
		Game.message(message)
