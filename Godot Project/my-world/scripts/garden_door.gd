extends "res://scripts/door.gd"

# The Museum's Garden Door, inside (tools/build_interiors.gd _museum): out to the town like the Museum's own exit, but
# into the Museum Garden. The garden is only made as the town loads (scripts/museum_garden.gd), after the player has
# already appeared at the Museum's front, so this leaves a note on Game and the garden moves her to its arbor.


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") and destination != "" and closed_message == "":
		Game.set_meta("museum_garden_exit", Time.get_ticks_msec())
	super(body)
