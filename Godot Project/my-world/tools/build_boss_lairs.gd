extends SceneTree

# Builds the bosses' own lairs (scripts/boss_lair.gd): res://scenes/bosses/clock_tower.tscn (Grandfather Tock's) and
# res://scenes/bosses/boulder_canyon.tscn (the Boulderdillo's). Each is a root with its script, an Entrance marker and
# the player. Everything inside is made by the lair's script when it loads (scripts/clock_tower.gd,
# scripts/boulder_canyon.gd), so changing a lair means changing that script. Re-run this only if a lair is added or
# renamed, or the scene's three nodes need to change.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/build_boss_lairs.gd [-- <RootName> ...]
# Names after -- build only those (so the others' scenes don't get new ids for nothing).

const LAIRS := [
	["TheClockworkTower", "res://scripts/clock_tower.gd", "res://scenes/bosses/clock_tower.tscn"],
	["BoulderCanyon", "res://scripts/boulder_canyon.gd", "res://scenes/bosses/boulder_canyon.tscn"],
	["TheSkyreachTrail", "res://scripts/skyreach_trail.gd", "res://scenes/bosses/skyreach_trail.tscn"],
]


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://scenes/bosses"))
	var only := OS.get_cmdline_user_args()
	for l in LAIRS:
		if not only.is_empty() and not only.has(l[0]):
			continue
		var root := Node3D.new()
		root.name = l[0]
		root.set_script(load(l[1]))
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
		print("SAVED ", l[2], " pack=", scene.pack(root), " save=", ResourceSaver.save(scene, l[2]))
		root.free()
	quit()
