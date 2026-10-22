extends Node3D

# The Scary World (scenes/scary_world/scary_world.tscn, built by tools/build_scary_world.gd): a small misty wood
# behind the locked gate in the far northwest. Nina only goes in if she says yes at the gate (dialogue/scary_gate.json),
# and can always go home: the gate behind her, or "Go home to town" in the pause menu.
# Spooky, but nothing here can hurt her. The centipede lives here (scripts/centipede_friend.gd).

const HOME_SPAWN := "FromScaryWorld"


func _ready() -> void:
	Dialogue.set_flag("scary_world_visited")
	Game.message.call_deferred("The Scary World. It's misty and strange... but nothing here can hurt you. The gate behind you goes home, any time.")


static func go_home() -> void:
	Game.go(Game.TOWN_SCENE, HOME_SPAWN, "town")
