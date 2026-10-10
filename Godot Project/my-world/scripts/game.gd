extends Node

# Autoload "Game": remembers where the player should appear after a scene change.

var next_spawn := ""


func go(scene_path: String, spawn: String) -> void:
	if not ResourceLoader.exists(scene_path):
		print("Door leads to %s, which isn't built yet" % scene_path)
		return
	next_spawn = spawn
	get_tree().call_deferred("change_scene_to_file", scene_path)
