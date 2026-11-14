extends SceneTree

# Checks that trees and plants don't grow through things (scripts/plant_clearance.gd; Hayden's day 1 playtest,
# 11 Nov 2026), and the other day 1 polish in the Void and Stars Hollow:
#   - the Void's trees and undergrowth leave out the ones standing in something solid, and only a few are left out
#   - no tree or plant that's left grows through anything solid
#   - Earth's autumn trees in something solid are hidden, trunk, leaves and solid box and all
#   - the grass only parts close round her, and not far
#   - town rails only where they make sense: never on a court, the soccer field or in the skate park, nor in a race's
#     lanes
#   - the old oak's runes are made of strokes (glyphs), not plain bars
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_plant_clearance.gd
#
# Your own save is put aside and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.plants_test_backup.json"
const TOWN := "res://scenes/town/town.tscn"
const EARTH := "res://scenes/earth/earth.tscn"
const PC := preload("res://scripts/plant_clearance.gd")

var failures := 0


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures += 1


func _initialize() -> void:
	create_timer(240.0, true, false, true).timeout.connect(func() -> void:
		print("RESULT FAILED (timed out)")
		_finish())
	_run.call_deferred()


func _top(d: Dictionary, n: int) -> String:
	var keys := d.keys()
	keys.sort_custom(func(a, b) -> bool: return d[a] > d[b])
	var out := []
	for k in keys.slice(0, n):
		out.append("%s x%d" % [k, d[k]])
	return ", ".join(out)


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	var game := root.get_node("Game")
	game.riding = false
	game._resume = {}
	game.pending_message = ""
	PC.blocked_by.clear()
	change_scene_to_file(TOWN)
	for i in 6:
		await process_frame
	await create_timer(4.6).timeout                    # the second look, after things put in at load (RECHECK)
	var town := current_scene as Node3D
	var trees := town.find_child("Trees", true, false)
	var foliage := town.find_child("Foliage", true, false)
	var tree_out: PackedInt32Array = trees.get("left_out")
	var n_trees: int = (trees.get("positions") as PackedVector3Array).size()
	var plants_out: int = foliage.get("left_out")
	var n_plants: int = (foliage.get("positions") as PackedVector3Array).size()
	print("  the Void: %d of %d trees and %d of %d plants left out; in the way: %s" % [tree_out.size(), n_trees,
		plants_out, n_plants, _top(PC.blocked_by, 12)])
	check(tree_out.size() < n_trees * 0.2, "most of the Void's trees still grow (%d of %d left out)" % [tree_out.size(), n_trees])
	check(plants_out < n_plants * 0.2, "most of the Void's plants still grow (%d of %d left out)" % [plants_out, n_plants])
	check(trees.get_node("Canopies").multimesh.instance_count > 0, "the trees are built")
	# Nothing left grows through anything: every remaining plant's own box is clear
	var through := 0
	var reach: PackedFloat32Array = foliage.get("_reach")
	PC.blocked_by.clear()
	for i in n_plants:
		if reach[i] > 0.0 and not foliage.call("_clear", i):
			through += 1
	check(through == 0, "no plant left grows through anything (%d: %s)" % [through, _top(PC.blocked_by, 6)])
	# The grass's shader only bends it close by, and not far
	var grass := foliage.get_node_or_null("Grass") as MultiMeshInstance3D
	var grass_mat: ShaderMaterial = grass.material_override if grass else null
	check(grass_mat != null and float(grass_mat.get_shader_parameter("reach")) <= 0.8
		and float(grass_mat.get_shader_parameter("push")) <= 0.4, "the grass parts only right round her, and not far")

	# Town rails: off the courts, the soccer field and the skate park, and out of the races' lanes (three that ran
	# inside buildings take themselves out as the town loads: grind_rail.gd inside_something())
	var rails := town.get_node("Town Rails").find_children("*", "GrindRail", true, false)
	check(rails.size() >= 17, "there are still rails round town (%d)" % rails.size())
	var areas := []
	for n in ["Basketball Court", "Tennis Court", "Soccer Field", "Skate Park"]:
		var a := town.find_child(n, false, false) as Node3D
		check(a != null, "found the %s" % n)
		if a:
			areas.append([n, Vector2(a.global_position.x, a.global_position.z)])
	var on_court := []
	for r in rails:
		var rail := r as GrindRail
		for t in 9:
			var p := rail.point_at(rail.length() * t / 8.0)
			for a in areas:
				var radius := 17.5 if a[0] != "Skate Park" else 16.5
				if Vector2(p.x, p.z).distance_to(a[1]) < radius:
					on_court.append("%s on the %s" % [rail.get_parent().name, a[0]])
	check(on_court.is_empty(), "no town rail on a court, the soccer field or the skate park %s" % [on_court.slice(0, 4)])
	var races: Dictionary = root.get_node("Races").TRACKS
	var in_lane := []
	for id in races:
		var tr: Dictionary = races[id]
		if not String(tr.scene).ends_with("town.tscn") or tr.get("sky", false):
			continue
		var pts: Array = tr.points
		for r in rails:
			var rail := r as GrindRail
			for t in 9:
				var p := rail.point_at(rail.length() * t / 8.0)
				var q := Vector2(p.x, p.z)
				for k in pts.size():
					var a: Vector2 = pts[k]
					var b: Vector2 = pts[(k + 1) % pts.size()]
					var f := clampf((q - a).dot(b - a) / (b - a).length_squared(), 0.0, 1.0)
					if q.distance_to(a.lerp(b, f)) < 6.0:
						in_lane.append("%s on %s" % [rail.get_parent().name, id])
	check(in_lane.is_empty(), "no town rail in a race's lanes %s" % [in_lane.slice(0, 4)])

	# Earth: its autumn trees
	PC.blocked_by.clear()
	change_scene_to_file(EARTH)
	for i in 6:
		await process_frame
	await create_timer(4.6).timeout
	var earth := current_scene as Node3D
	var gone: int = earth.get("trees_left_out")
	var at := earth.get_node("Autumn Trees")
	var trunks := (at.get_node("Tree Trunk").get("transforms") as PackedFloat32Array).size() / 12
	print("  Earth: %d trees left out of about %d; in the way: %s" % [gone, trunks, _top(PC.blocked_by, 12)])
	check(gone < trunks * 0.25, "most of Earth's trees still grow (%d left out)" % gone)
	var hidden := 0
	var xf: PackedFloat32Array = at.get_node("Tree Leaves").get("transforms")
	for i in xf.size() / 12:
		if xf[i * 12 + 10] < -400.0:
			hidden += 1
	check((gone == 0) == (hidden == 0), "a tree left out loses its leaves too (%d balls hidden)" % hidden)
	# The oak's runes: glyphs of several strokes each
	var runes := earth.find_child("Oak Runes", true, false)
	check(runes != null and runes.get_child_count() >= 29 * 3, "the old oak's runes are glyphs of strokes (%d strokes)" % (runes.get_child_count() if runes else 0))
	check(runes != null and runes.get_child(0) is MeshInstance3D and (runes.get_child(0) as MeshInstance3D).material_override.resource_name == "Oak Rune",
		"they share the Oak Rune material the oak lights")
	_end()


func _end() -> void:
	print("RESULT %s (%d failures)" % ["PASSED" if failures == 0 else "FAILED", failures])
	_finish()


func _finish() -> void:
	if FileAccess.file_exists(BACKUP):
		DirAccess.remove_absolute(SAVE)
		DirAccess.rename_absolute(BACKUP, SAVE)
	quit(1 if failures > 0 else 0)
