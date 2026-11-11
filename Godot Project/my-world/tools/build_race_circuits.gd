extends SceneTree

# Builds res://scenes/races/<id>.tscn, one for each race circuit (the tracks in scripts/races.gd with a "circuit"):
# a root with scripts/race_circuit.gd, an Entrance marker and the player. The circuit itself (sky, ground, road,
# walls, scenery) is made by race_circuit.gd when it loads, from the track's points, so changing a track only means
# changing its entry in Races.TRACKS. Re-run this only when a circuit is added or renamed.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/build_race_circuits.gd

const CIRCUITS := ["lake_loop", "meadow_wiggle", "observatory_hill", "pumpkin_run"]


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://scenes/races"))
	for id in CIRCUITS:
		var root := Node3D.new()
		root.name = str(id).to_pascal_case() + "Circuit"
		root.set_script(load("res://scripts/race_circuit.gd"))
		root.set("circuit_id", id)
		var entrance := Marker3D.new()
		entrance.name = "Entrance"
		entrance.position = Vector3(0, 1, 0)
		root.add_child(entrance)
		entrance.owner = root
		var player: Node3D = load("res://scenes/player/player.tscn").instantiate()
		player.name = "Player"
		player.position = Vector3(0, 1, 0)
		root.add_child(player)
		player.owner = root
		var scene := PackedScene.new()
		var out := "res://scenes/races/%s.tscn" % id
		print("SAVED ", out, " pack=", scene.pack(root), " save=", ResourceSaver.save(scene, out))
		root.free()
	quit()
