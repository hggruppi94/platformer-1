extends SceneTree

# Builds res://scenes/bosses/arena.tscn, the Star Arena: a root with scripts/arena_level.gd, an Entrance marker and the
# player. The arena itself (the floor, the wall and stands, the tunnel, the hatches, the spotlights, the crowd, Blip and
# the Round Board) is made by arena_level.gd when it loads, so changing it means changing that script. Re-run this only
# if the scene's three nodes need to change.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/build_arena.gd


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://scenes/bosses"))
	var root := Node3D.new()
	root.name = "StarArena"
	root.set_script(load("res://scripts/arena_level.gd"))
	var entrance := Marker3D.new()
	entrance.name = "Entrance"
	entrance.position = Vector3(0, 1, 36)
	root.add_child(entrance)
	entrance.owner = root
	var player: Node3D = load("res://scenes/player/player.tscn").instantiate()
	player.name = "Player"
	player.position = Vector3(0, 1, 36)
	root.add_child(player)
	player.owner = root
	var scene := PackedScene.new()
	var out := "res://scenes/bosses/arena.tscn"
	print("SAVED ", out, " pack=", scene.pack(root), " save=", ResourceSaver.save(scene, out))
	root.free()
	quit()
