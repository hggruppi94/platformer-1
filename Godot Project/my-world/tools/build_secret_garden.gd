extends SceneTree

# Builds res://scenes/secret_garden/secret_garden.tscn, the real Secret Garden behind the ivy wall: a root with
# scripts/secret_garden.gd, an Entrance marker and the player. The garden itself (its walls, the Rose Walk, the
# fountain, the maze, the pond, the giant flowers, the Great Tree and the sleeping seeds) is made by secret_garden.gd
# when it loads, so changing it means changing that script. Re-run this only if the scene's three nodes change.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/build_secret_garden.gd


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://scenes/secret_garden"))
	var root := Node3D.new()
	root.name = "SecretGarden"
	root.set_script(load("res://scripts/secret_garden.gd"))
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
	var out := "res://scenes/secret_garden/secret_garden.tscn"
	print("SAVED ", out, " pack=", scene.pack(root), " save=", ResourceSaver.save(scene, out))
	root.free()
	quit()
