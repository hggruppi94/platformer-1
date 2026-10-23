extends Node3D

# The Practice Park (tools/build_skate_test.gd): Nina arrives on her board, ready to skate. If she hasn't picked up
# the skateboard at the town's Skate Park yet, she's given it here, since there's nothing else to do in a skate park.


func _ready() -> void:
	if not Game.has_item("skateboard"):
		Game.items.append("skateboard")
	if not Game.riding:
		Game.riding = true
		Game.equipment_changed.emit()
	Game.message("The Practice Park! Hold %s to crouch and let go to ollie. %s grinds rails and ledges." %
		[Settings.key_name("jump"), Settings.key_name("skate_grind")])
