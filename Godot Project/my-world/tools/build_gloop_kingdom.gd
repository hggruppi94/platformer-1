extends SceneTree

# Builds res://scenes/bosses/gloop_kingdom.tscn, the Gloop King's own domain: a root with scripts/gloop_kingdom.gd, an
# Entrance marker and the player. The kingdom itself (the Bog Road, the moat, the palace gate, the court, the throne,
# the King and his guards) is made by gloop_kingdom.gd when it loads, so changing it means changing that script. Re-run
# this only if the scene's three nodes need to change.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/build_gloop_kingdom.gd


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://scenes/bosses"))
	var root := Node3D.new()
	root.name = "GloopKingdom"
	root.set_script(load("res://scripts/gloop_kingdom.gd"))
	var entrance := Marker3D.new()
	entrance.name = "Entrance"
	entrance.position = Vector3(0, 1, 3)
	root.add_child(entrance)
	entrance.owner = root
	var player: Node3D = load("res://scenes/player/player.tscn").instantiate()
	player.name = "Player"
	player.position = Vector3(0, 1, 3)
	root.add_child(player)
	player.owner = root
	var scene := PackedScene.new()
	var out := "res://scenes/bosses/gloop_kingdom.tscn"
	print("SAVED ", out, " pack=", scene.pack(root), " save=", ResourceSaver.save(scene, out))
	root.free()
	quit()
