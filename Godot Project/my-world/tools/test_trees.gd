extends SceneTree

# Checks Galaxity's sparkly alien trees (scenes/town/trees.gd): every tree is built, all three kinds (orb, spire,
# parasol) grow in town, a tree's kind comes from its spot, the canopies, spires, trunks and twinkles are all there,
# every twinkle sits on its tree's canopy, and the twinkle sheet from pixelfx loads with its 16 frames.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_trees.gd
#
# Your own save is put aside and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.trees_test_backup.json"
const TOWN := "res://scenes/town/town.tscn"
const TREES := preload("res://scenes/town/trees.gd")

var failures := 0


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures += 1


func _initialize() -> void:
	create_timer(120.0, true, false, true).timeout.connect(func() -> void:
		print("RESULT FAILED (timed out)")
		_finish())
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	var game := root.get_node("Game")
	game.riding = false
	game._resume = {}
	game.pending_message = ""
	change_scene_to_file(TOWN)
	for i in 6:
		await process_frame
	var town := current_scene as Node3D
	var trees := town.find_child("Trees", true, false)
	check(trees != null and trees.get_script() == TREES, "the town has its Trees")
	if trees == null:
		_end()
		return
	var positions: PackedVector3Array = trees.get("positions")
	var sizes: PackedFloat32Array = trees.get("sizes")
	var kinds: PackedInt32Array = trees.get("kinds")
	check(positions.size() > 200, "there are lots of trees (%d)" % positions.size())
	check(kinds.size() == positions.size(), "every tree has a kind")
	var counts := [0, 0, 0]
	var same := true
	for i in kinds.size():
		counts[kinds[i]] += 1
		same = same and kinds[i] == TREES.kind_of(positions[i])
	check(counts.min() > positions.size() / 6, "orb, spire and parasol trees all grow (%s)" % [counts])
	check(same, "a tree's kind comes from its spot")

	for part in ["Canopies", "Spires", "Trunks", "Twinkles"]:
		var n := trees.get_node_or_null(part) as MultiMeshInstance3D
		check(n != null and n.multimesh != null and n.multimesh.instance_count > 0, "%s are built" % part)
	var twinkles := trees.get_node_or_null("Twinkles") as MultiMeshInstance3D
	check(twinkles != null and twinkles.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
		"twinkles cast no shadows")
	check(twinkles != null and twinkles.multimesh.use_custom_data, "each twinkle has its own timing")

	# Every twinkle is close to a tree, up in its canopy rather than on the ground
	var spots: PackedVector3Array = trees.get("twinkle_spots")
	check(spots.size() >= positions.size() * 5, "five or more twinkles a tree (%d)" % spots.size())
	var stray := 0
	for at in spots:
		var near := false
		for i in positions.size():
			var flat := Vector2(at.x - positions[i].x, at.z - positions[i].z).length()
			if flat < sizes[i] * 2.2 + 1.0 and at.y > positions[i].y + 1.0 and at.y < positions[i].y + 4.0 + sizes[i] * 3.5:
				near = true
				break
		if not near:
			stray += 1
	check(stray == 0, "every twinkle sits on a tree's canopy (%d stray)" % stray)

	var sheet := load("res://scenes/town/tree_twinkle.png") as Texture2D
	check(sheet != null and sheet.get_width() == 128 and sheet.get_height() == 128,
		"the pixelfx twinkle sheet loads (4 x 4 frames of 32 px)")
	_end()


func _end() -> void:
	print("RESULT %s (%d failed)" % ["OK" if failures == 0 else "FAILED", failures])
	_finish()


func _finish() -> void:
	if FileAccess.file_exists(BACKUP):
		DirAccess.rename_absolute(BACKUP, SAVE)
	quit(1 if failures > 0 else 0)
